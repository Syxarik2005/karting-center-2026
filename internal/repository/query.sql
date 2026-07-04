-- name: CreateClient :one
INSERT INTO clients (name, phone)
VALUES ($1, $2)
RETURNING *;

-- name: GetClientByPhone :one
SELECT * FROM clients
WHERE phone = $1 LIMIT 1;

-- name: GetClientByID :one
SELECT * FROM clients
WHERE id = $1 LIMIT 1;

-- name: ListSlots :many
SELECT s.id, s.start_time, s.track_config, s.max_karts, s.available_karts,
       s.rental_tariff, s.gathering_place, s.status,
       m.id AS marshal_id, m.name AS marshal_name, m.avatar_url AS marshal_avatar_url, m.rating AS marshal_rating
FROM slots s
JOIN marshals m ON s.marshal_id = m.id
WHERE s.start_time >= $1 AND s.start_time <= $2
ORDER BY s.start_time ASC
LIMIT $3 OFFSET $4;

-- name: GetSlotByID :one
SELECT s.id, s.start_time, s.track_config, s.max_karts, s.available_karts,
       s.rental_tariff, s.gathering_place, s.status,
       m.id AS marshal_id, m.name AS marshal_name, m.avatar_url AS marshal_avatar_url, m.rating AS marshal_rating
FROM slots s
JOIN marshals m ON s.marshal_id = m.id
WHERE s.id = $1 LIMIT 1;

-- name: CreateBooking :one
-- The claim_kart_on_booking trigger enforces BR-01 (atomic availability) and
-- raises NO_KARTS_AVAILABLE / SLOT_GONE — the handler maps those to 409/410.
INSERT INTO bookings (slot_id, client_id, gear_type)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdateBookingStatus :one
UPDATE bookings
SET status = $2,
    cancellation_reason = COALESCE(sqlc.narg(cancellation_reason), cancellation_reason),
    cancelled_at = CASE WHEN $2 IN ('CANCELLED_BY_CLIENT', 'CANCELLED_BY_CENTER') THEN NOW() ELSE cancelled_at END
WHERE id = $1
RETURNING *;

-- name: GetBookingByID :one
SELECT * FROM bookings
WHERE id = $1 LIMIT 1;

-- name: ListBookingsByClient :many
SELECT b.* FROM bookings b
JOIN slots s ON b.slot_id = s.id
WHERE b.client_id = $1
ORDER BY s.start_time DESC
LIMIT $2 OFFSET $3;

-- name: CreateRating :one
INSERT INTO ratings (booking_id, marshal_id, rating, comment)
VALUES ($1, $2, $3, $4)
RETURNING *;
