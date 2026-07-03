package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"volna-backend/internal/repository"
	"volna-backend/pkg/auth"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

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

	r.Group(func(r chi.Router) {
		r.Get("/auth/profile", s.GetProfile)
		r.Post("/bookings", s.CreateBooking)
		r.Get("/bookings", s.GetBookings)
		r.Post("/bookings/{id}/cancel", s.CancelBooking)
		r.Post("/bookings/{id}/rate", s.RateBooking)
	})
}

// ---------- helpers ----------

func respondJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
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
	SlotID      string `json:"slot_id"`
	SeatsCount  int32  `json:"seats_count"`
	RentalCount int32  `json:"rental_count"`
}

type RateBookingRequest struct {
	Rating  int32  `json:"rating"`
	Comment string `json:"comment"`
}

// ---------- Auth handlers ----------

func (s *Server) SendCode(w http.ResponseWriter, r *http.Request) {
	var req SendCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	if req.Phone == "" {
		http.Error(w, "Phone is required", http.StatusBadRequest)
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
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	if req.Code != "0000" {
		http.Error(w, "Invalid OTP code", http.StatusUnauthorized)
		return
	}

	ctx := r.Context()
	client, err := s.repo.GetClientByPhone(ctx, req.Phone)
	isNew := false
	if err != nil {
		// Client not found → create
		if req.Name == "" {
			req.Name = "User"
		}
		client, err = s.repo.CreateClient(ctx, repository.CreateClientParams{
			Name:  req.Name,
			Phone: req.Phone,
		})
		if err != nil {
			http.Error(w, "Failed to create client", http.StatusInternalServerError)
			return
		}
		isNew = true
	}

	token, err := s.jwt.GenerateToken(client.ID, 24*time.Hour)
	if err != nil {
		http.Error(w, "Failed to generate token", http.StatusInternalServerError)
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"token":  token,
		"is_new": isNew,
		"client": client,
	})
}

func (s *Server) GetProfile(w http.ResponseWriter, r *http.Request) {
	clientID, err := s.extractClientID(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	client, err := s.repo.GetClientByID(r.Context(), clientID)
	if err != nil {
		http.Error(w, "Client not found", http.StatusNotFound)
		return
	}

	respondJSON(w, http.StatusOK, client)
}

// ---------- Slots handlers ----------

func (s *Server) GetSlots(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	now := time.Now()

	startDate := pgtype.Timestamptz{Time: now, Valid: true}
	endDate := pgtype.Timestamptz{Time: now.AddDate(0, 0, 7), Valid: true}

	// Parse optional query params
	if df := r.URL.Query().Get("date_from"); df != "" {
		if t, err := time.Parse("2006-01-02", df); err == nil {
			startDate = pgtype.Timestamptz{Time: t, Valid: true}
			endDate = pgtype.Timestamptz{Time: t.AddDate(0, 0, 7), Valid: true}
		}
	}
	if dt := r.URL.Query().Get("date_to"); dt != "" {
		if t, err := time.Parse("2006-01-02", dt); err == nil {
			endDate = pgtype.Timestamptz{Time: t.Add(24*time.Hour - time.Second), Valid: true}
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
		StartAt:   startDate,
		StartAt_2: endDate,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		http.Error(w, "Failed to fetch slots", http.StatusInternalServerError)
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
		http.Error(w, "Invalid slot ID", http.StatusBadRequest)
		return
	}

	slot, err := s.repo.GetSlotByID(r.Context(), slotID)
	if err != nil {
		http.Error(w, "Slot not found", http.StatusNotFound)
		return
	}
	respondJSON(w, http.StatusOK, slot)
}

// ---------- Booking handlers ----------

func (s *Server) CreateBooking(w http.ResponseWriter, r *http.Request) {
	clientID, err := s.extractClientID(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req BookingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	slotID, err := parsePgtypeUUID(req.SlotID)
	if err != nil {
		http.Error(w, "Invalid slot_id", http.StatusBadRequest)
		return
	}

	booking, err := s.repo.CreateBooking(r.Context(), repository.CreateBookingParams{
		ClientID:    clientID,
		SlotID:      slotID,
		SeatsCount:  req.SeatsCount,
		RentalCount: req.RentalCount,
		PriceTotal:  pgtype.Numeric{Valid: false}, // calculated by DB trigger
	})
	if err != nil {
		http.Error(w, "Conflict: "+err.Error(), http.StatusConflict)
		return
	}
	respondJSON(w, http.StatusCreated, booking)
}

func (s *Server) GetBookings(w http.ResponseWriter, r *http.Request) {
	clientID, err := s.extractClientID(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
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
		http.Error(w, "Failed to fetch bookings", http.StatusInternalServerError)
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
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	bookingIDStr := chi.URLParam(r, "id")
	bookingID, err := parsePgtypeUUID(bookingIDStr)
	if err != nil {
		http.Error(w, "Invalid booking ID", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	booking, err := s.repo.GetBookingByID(ctx, bookingID)
	if err != nil {
		http.Error(w, "Booking not found", http.StatusNotFound)
		return
	}

	slot, err := s.repo.GetSlotByID(ctx, booking.SlotID)
	if err != nil {
		http.Error(w, "Failed to retrieve slot details", http.StatusInternalServerError)
		return
	}

	// Enforce 2h cancellation window
	if time.Now().Add(2 * time.Hour).After(slot.StartAt.Time) {
		respondJSON(w, http.StatusBadRequest, map[string]string{
			"code":    "too_close",
			"message": "Cannot cancel booking less than 2 hours before the start time",
		})
		return
	}

	updated, err := s.repo.UpdateBookingStatus(ctx, repository.UpdateBookingStatusParams{
		ID:     bookingID,
		Status: repository.BookingStatusCancelled,
	})
	if err != nil {
		http.Error(w, "Failed to cancel booking: "+err.Error(), http.StatusInternalServerError)
		return
	}
	respondJSON(w, http.StatusOK, updated)
}

func (s *Server) RateBooking(w http.ResponseWriter, r *http.Request) {
	_, err := s.extractClientID(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	bookingIDStr := chi.URLParam(r, "id")
	bookingID, err := parsePgtypeUUID(bookingIDStr)
	if err != nil {
		http.Error(w, "Invalid booking ID", http.StatusBadRequest)
		return
	}

	var req RateBookingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	if req.Rating < 1 || req.Rating > 5 {
		http.Error(w, "Rating must be between 1 and 5", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	booking, err := s.repo.GetBookingByID(ctx, bookingID)
	if err != nil {
		http.Error(w, "Booking not found", http.StatusNotFound)
		return
	}

	slot, err := s.repo.GetSlotByID(ctx, booking.SlotID)
	if err != nil {
		http.Error(w, "Failed to retrieve slot details", http.StatusInternalServerError)
		return
	}

	comment := pgtype.Text{
		String: req.Comment,
		Valid:  req.Comment != "",
	}

	rating, err := s.repo.CreateRating(ctx, repository.CreateRatingParams{
		BookingID:    bookingID,
		InstructorID: slot.InstructorID,
		Rating:        req.Rating,
		Comment:      comment,
	})
	if err != nil {
		http.Error(w, "Failed to submit rating: "+err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, http.StatusCreated, rating)
}
