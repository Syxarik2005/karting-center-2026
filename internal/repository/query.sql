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
SELECT s.id, s.start_at, s.total_seats AS max_seats, (s.total_seats - s.free_seats) AS booked_seats, s.free_rental_boards, s.price AS price_per_seat, s.rental_price AS price_rental,
       s.meeting_point, s.meeting_point_lat, s.meeting_point_lng, s.status,
       r.id as route_id, r.name as route_name, r.description as route_description, r.type as route_type, r.duration_min as duration_minutes, r.geometry as route_geometry,
       i.id as instructor_id, i.name as instructor_name
FROM slots s
JOIN routes r ON s.route_id = r.id
JOIN instructors i ON s.instructor_id = i.id
WHERE s.start_at >= $1 AND s.start_at <= $2
ORDER BY s.start_at ASC
LIMIT $3 OFFSET $4;

-- name: GetSlotByID :one
SELECT s.id, s.start_at, s.total_seats AS max_seats, (s.total_seats - s.free_seats) AS booked_seats, s.free_rental_boards, s.price AS price_per_seat, s.rental_price AS price_rental,
       s.meeting_point, s.meeting_point_lat, s.meeting_point_lng, s.status,
       r.id as route_id, r.name as route_name, r.description as route_description, r.type as route_type, r.duration_min as duration_minutes, r.geometry as route_geometry,
       i.id as instructor_id, i.name as instructor_name
FROM slots s
JOIN routes r ON s.route_id = r.id
JOIN instructors i ON s.instructor_id = i.id
WHERE s.id = $1 LIMIT 1;

-- name: CreateBooking :one
INSERT INTO bookings (slot_id, client_id, seats_count, rental_count, price_total)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: UpdateBookingStatus :one
UPDATE bookings
SET status = $2, cancelled_at = CASE WHEN $2 = 'cancelled'::booking_status OR $2 = 'late_cancel'::booking_status THEN NOW() ELSE cancelled_at END
WHERE id = $1
RETURNING *;

-- name: GetBookingByID :one
SELECT * FROM bookings
WHERE id = $1 LIMIT 1;

-- name: ListBookingsByClient :many
SELECT b.* FROM bookings b
JOIN slots s ON b.slot_id = s.id
WHERE b.client_id = $1
ORDER BY s.start_at DESC
LIMIT $2 OFFSET $3;

-- name: CreateRating :one
INSERT INTO ratings (booking_id, instructor_id, rating, comment)
VALUES ($1, $2, $3, $4)
RETURNING *;
