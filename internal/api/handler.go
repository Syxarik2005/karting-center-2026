package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"apex-backend/internal/repository"
	"apex-backend/pkg/auth"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

// Cancellation cutoff. The customer brief (0-customer-brief/customer-brief.md)
// only flags a same-day cancellation as "a problem" without giving an exact
// number — see domain-description.md, open question #1. 60 minutes matches
// the value used in 02-development/client's mock API (mockApi.ts,
// CANCEL_CUTOFF_MINUTES) so both implementations agree until Denis confirms
// the real threshold.
const cancelCutoff = 60 * time.Minute

type Server struct {
	repo repository.Querier
	jwt  auth.TokenManager
}

func NewServer(repo repository.Querier, jwtManager auth.TokenManager) *Server {
	return &Server{
		repo: repo,
		jwt:  jwtManager,
	}
}

func (s *Server) Mount(r chi.Router) {
	r.Post("/auth/send-code", s.SendCode)
	r.Post("/auth/login", s.Login)
	r.Get("/slots", s.GetSlots)
	r.Get("/slots/{id}", s.GetSlotByID)

	r.Route("/client", func(r chi.Router) {
		r.Post("/bookings", s.CreateBooking)
		r.Get("/bookings", s.GetBookings)
		r.Post("/bookings/{id}/cancel", s.CancelBooking)
		r.Post("/bookings/{id}/rate", s.RateBooking)
		r.Get("/profile", s.GetProfile)
	})
}

// ---------- helpers ----------

// ErrorResponse mirrors 01-analysis/api/openapi.yaml components.schemas.ErrorResponse.
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func respondJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func respondError(w http.ResponseWriter, status int, code, message string) {
	respondJSON(w, status, ErrorResponse{Code: code, Message: message})
}

func (s *Server) extractClientID(r *http.Request) (pgtype.UUID, error) {
	authHeader := r.Header.Get("Authorization")
	if len(authHeader) < 8 {
		return pgtype.UUID{}, http.ErrNoCookie // reuse as sentinel
	}
	return s.jwt.ParseToken(authHeader[7:])
}

func parsePgtypeUUID(str string) (pgtype.UUID, error) {
	return auth.ParseUUIDString(str)
}

// bookingCreationErrorCode inspects the error raised by the claim_kart_on_booking
// trigger (db_init.sql) and maps it to the HTTP status + error code the client
// expects (see 01-analysis/api/openapi.yaml and FEAT-002-booking-flow.md).
func bookingCreationErrorCode(err error) (status int, code string) {
	msg := err.Error()
	switch {
	case strings.Contains(msg, "NO_KARTS_AVAILABLE"):
		return http.StatusConflict, "NO_KARTS_AVAILABLE"
	case strings.Contains(msg, "SLOT_GONE"):
		return http.StatusGone, "SLOT_GONE"
	default:
		return http.StatusInternalServerError, "INTERNAL_ERROR"
	}
}

// ---------- request DTOs ----------

type SendCodeRequest struct {
	Phone string `json:"phone"`
}

type LoginRequest struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
	Name  string `json:"name"`
}

type BookingRequest struct {
	SlotID   string `json:"slot_id"`
	GearType string `json:"gear_type"` // "OWN" | "RENTAL"
}

type RateBookingRequest struct {
	Rating  int32  `json:"rating"`
	Comment string `json:"comment"`
}

// ---------- Auth handlers ----------
// NOTE: authentication is not part of 01-analysis/api/openapi.yaml (the
// client-app contract assumes an already-authenticated client, per R-004/R-028
// in customer-brief.md). This flow exists as an additional backend exercise
// for the "смежные роли" part of the assignment and is intentionally simple
// (mock SMS code) — see root README.md for how this fits with 02-development.

func (s *Server) SendCode(w http.ResponseWriter, r *http.Request) {
	var req SendCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_BODY", "Invalid request body")
		return
	}
	if req.Phone == "" {
		respondError(w, http.StatusBadRequest, "PHONE_REQUIRED", "Phone is required")
		return
	}
	// MVP: mock SMS — code is always "0000"
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"message":              "Code sent successfully",
		"ttl_seconds":          300,
		"resend_after_seconds": 60,
	})
}

func (s *Server) Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_BODY", "Invalid request body")
		return
	}
	if req.Code != "0000" {
		respondError(w, http.StatusUnauthorized, "INVALID_CODE", "Invalid OTP code")
		return
	}

	ctx := r.Context()
	client, err := s.repo.GetClientByPhone(ctx, req.Phone)
	isNew := false
	if err != nil {
		if req.Name == "" {
			req.Name = "Клиент"
		}
		client, err = s.repo.CreateClient(ctx, repository.CreateClientParams{
			Name:  req.Name,
			Phone: req.Phone,
		})
		if err != nil {
			respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to create client")
			return
		}
		isNew = true
	}

	token, err := s.jwt.GenerateToken(client.ID, 24*time.Hour)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to generate token")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"token":  token,
		"is_new": isNew,
		"client": client,
	})
}

// ---------- Slots handlers ----------

func (s *Server) GetSlots(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	now := time.Now()

	startTime := pgtype.Timestamptz{Time: now, Valid: true}
	endTime := pgtype.Timestamptz{Time: now.AddDate(0, 0, 7), Valid: true} // R-027: 7-day default horizon

	if df := r.URL.Query().Get("date_from"); df != "" {
		if t, err := time.Parse(time.RFC3339, df); err == nil {
			startTime = pgtype.Timestamptz{Time: t, Valid: true}
		}
	}
	if dt := r.URL.Query().Get("date_to"); dt != "" {
		if t, err := time.Parse(time.RFC3339, dt); err == nil {
			endTime = pgtype.Timestamptz{Time: t, Valid: true}
		}
	}

	var limit int32 = 50
	var offset int32 = 0
	if l := r.URL.Query().Get("limit"); l != "" {
		if v, err := strconv.Atoi(l); err == nil && v > 0 && v <= 100 {
			limit = int32(v)
		}
	}
	if o := r.URL.Query().Get("offset"); o != "" {
		if v, err := strconv.Atoi(o); err == nil && v >= 0 {
			offset = int32(v)
		}
	}

	slots, err := s.repo.ListSlots(ctx, repository.ListSlotsParams{
		StartTime:   startTime,
		StartTime_2: endTime,
		Limit:       limit,
		Offset:      offset,
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to fetch slots")
		return
	}
	if slots == nil {
		slots = []repository.ListSlotsRow{}
	}
	respondJSON(w, http.StatusOK, slots)
}

func (s *Server) GetSlotByID(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	slotID, err := parsePgtypeUUID(idStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_ID", "Invalid slot ID")
		return
	}

	slot, err := s.repo.GetSlotByID(r.Context(), slotID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Слот не найден")
		return
	}
	respondJSON(w, http.StatusOK, slot)
}

// ---------- Booking handlers ----------

func (s *Server) CreateBooking(w http.ResponseWriter, r *http.Request) {
	clientID, err := s.extractClientID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized")
		return
	}

	var req BookingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_BODY", "Invalid request body")
		return
	}

	slotID, err := parsePgtypeUUID(req.SlotID)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_SLOT_ID", "Invalid slot_id")
		return
	}

	gearType := repository.GearType(req.GearType)
	if gearType != repository.GearTypeOwn && gearType != repository.GearTypeRental {
		respondError(w, http.StatusBadRequest, "INVALID_GEAR_TYPE", "gear_type must be OWN or RENTAL")
		return
	}

	booking, err := s.repo.CreateBooking(r.Context(), repository.CreateBookingParams{
		ClientID: clientID,
		SlotID:   slotID,
		GearType: gearType,
	})
	if err != nil {
		status, code := bookingCreationErrorCode(err)
		respondError(w, status, code, "Не удалось создать бронирование")
		return
	}
	respondJSON(w, http.StatusCreated, booking)
}

func (s *Server) GetBookings(w http.ResponseWriter, r *http.Request) {
	clientID, err := s.extractClientID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized")
		return
	}

	var limit int32 = 50
	var offset int32 = 0
	if l := r.URL.Query().Get("limit"); l != "" {
		if v, err := strconv.Atoi(l); err == nil && v > 0 {
			limit = int32(v)
		}
	}
	if o := r.URL.Query().Get("offset"); o != "" {
		if v, err := strconv.Atoi(o); err == nil && v >= 0 {
			offset = int32(v)
		}
	}

	bookings, err := s.repo.ListBookingsByClient(r.Context(), repository.ListBookingsByClientParams{
		ClientID: clientID,
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to fetch bookings")
		return
	}
	if bookings == nil {
		bookings = []repository.Booking{}
	}
	respondJSON(w, http.StatusOK, bookings)
}

func (s *Server) CancelBooking(w http.ResponseWriter, r *http.Request) {
	_, err := s.extractClientID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized")
		return
	}

	bookingIDStr := chi.URLParam(r, "id")
	bookingID, err := parsePgtypeUUID(bookingIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_ID", "Invalid booking ID")
		return
	}

	ctx := r.Context()
	booking, err := s.repo.GetBookingByID(ctx, bookingID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Бронирование не найдено")
		return
	}

	slot, err := s.repo.GetSlotByID(ctx, booking.SlotID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve slot details")
		return
	}

	if time.Now().Add(cancelCutoff).After(slot.StartTime.Time) {
		respondError(w, http.StatusBadRequest, "CANCEL_TOO_LATE",
			"Отмена невозможна менее чем за 60 минут до старта")
		return
	}

	updated, err := s.repo.UpdateBookingStatus(ctx, repository.UpdateBookingStatusParams{
		ID:     bookingID,
		Status: repository.BookingStatusCancelledByClient,
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to cancel booking")
		return
	}
	respondJSON(w, http.StatusOK, updated)
}

func (s *Server) RateBooking(w http.ResponseWriter, r *http.Request) {
	_, err := s.extractClientID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized")
		return
	}

	bookingIDStr := chi.URLParam(r, "id")
	bookingID, err := parsePgtypeUUID(bookingIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_ID", "Invalid booking ID")
		return
	}

	var req RateBookingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_BODY", "Invalid request body")
		return
	}
	if req.Rating < 1 || req.Rating > 5 {
		respondError(w, http.StatusBadRequest, "INVALID_RATING", "Rating must be between 1 and 5")
		return
	}

	ctx := r.Context()
	booking, err := s.repo.GetBookingByID(ctx, bookingID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Бронирование не найдено")
		return
	}

	slot, err := s.repo.GetSlotByID(ctx, booking.SlotID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve slot details")
		return
	}

	comment := pgtype.Text{
		String: req.Comment,
		Valid:  req.Comment != "",
	}

	rating, err := s.repo.CreateRating(ctx, repository.CreateRatingParams{
		BookingID: bookingID,
		MarshalID: slot.MarshalID,
		Rating:    req.Rating,
		Comment:   comment,
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to submit rating")
		return
	}

	respondJSON(w, http.StatusCreated, rating)
}

// ---------- Profile handler ----------

func (s *Server) GetProfile(w http.ResponseWriter, r *http.Request) {
	clientID, err := s.extractClientID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized")
		return
	}

	client, err := s.repo.GetClientByID(r.Context(), clientID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Профиль не найден")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"id":         client.ID,
		"name":       client.Name,
		"phone":      client.Phone,
		"is_regular": client.IsRegular,
	})
}
