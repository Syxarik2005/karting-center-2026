-- PostgreSQL Database Initialization Migration for "Volna" SUP-boarding Club

-- Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Enums Creation
CREATE TYPE route_type AS ENUM ('novice', 'experienced');
CREATE TYPE slot_status AS ENUM ('scheduled', 'cancelled');
CREATE TYPE booking_status AS ENUM ('active', 'cancelled', 'late_cancel', 'club_cancelled');

-- 2. Table: clients
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 3. Table: routes
CREATE TABLE routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type route_type NOT NULL,
    capacity_cap INT NOT NULL,
    duration_min INT NOT NULL CHECK (duration_min > 0),
    geometry TEXT NOT NULL, -- Polyline coordinates or encoded polyline
    
    -- Constraint: Novice routes cap at 8, experienced cap at 12 (Domain Constraints)
    CONSTRAINT chk_route_capacity CHECK (
        (type = 'novice' AND capacity_cap <= 8) OR
        (type = 'experienced' AND capacity_cap <= 12)
    )
);

-- 4. Table: instructors
CREATE TABLE instructors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.00
);


-- 5. Table: slots
CREATE TABLE slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE RESTRICT,
    instructor_id UUID NOT NULL REFERENCES instructors(id) ON DELETE RESTRICT,
    start_at TIMESTAMP WITH TIME ZONE NOT NULL,
    total_seats INT NOT NULL,
    free_seats INT NOT NULL,
    free_rental_boards INT NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    rental_price NUMERIC(10, 2) NOT NULL CHECK (rental_price >= 0),
    meeting_point TEXT NOT NULL,
    meeting_point_lat DOUBLE PRECISION NOT NULL,
    meeting_point_lng DOUBLE PRECISION NOT NULL,
    status slot_status NOT NULL DEFAULT 'scheduled',

    -- Constraints
    -- Max boards in club is 12 (Domain Constraint)
    CONSTRAINT chk_free_rental_boards CHECK (free_rental_boards >= 0 AND free_rental_boards <= 12),
    -- Seats must be non-negative and free seats cannot exceed total seats
    CONSTRAINT chk_seats_range CHECK (free_seats >= 0 AND free_seats <= total_seats),
    -- Slots total seats cannot exceed the club board limit (12 boards)
    CONSTRAINT chk_total_seats_limit CHECK (total_seats >= 1 AND total_seats <= 12)
);

-- 6. Table: bookings
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slot_id UUID NOT NULL REFERENCES slots(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    seats_count INT NOT NULL,
    rental_count INT NOT NULL,
    status booking_status NOT NULL DEFAULT 'active',
    price_total NUMERIC(10, 2) NOT NULL CHECK (price_total >= 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    cancelled_at TIMESTAMP WITH TIME ZONE,

    -- Business Rules Constraints
    -- A single booking can reserve 1 to 3 spots (US-5, R-013)
    CONSTRAINT chk_booking_seats_limit CHECK (seats_count >= 1 AND seats_count <= 3),
    -- Rental boards cannot exceed the number of booked seats
    CONSTRAINT chk_rental_boards_limit CHECK (rental_count >= 0 AND rental_count <= seats_count)
);

-- 6b. Table: ratings
CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    instructor_id UUID NOT NULL REFERENCES instructors(id) ON DELETE RESTRICT,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);


-- 7. Triggers to enforce complex domain invariants

-- A: Check that Slot's total_seats does not exceed the associated Route's capacity_cap
CREATE OR REPLACE FUNCTION check_slot_total_seats() 
RETURNS TRIGGER AS $$
DECLARE
    max_cap INT;
BEGIN
    SELECT capacity_cap INTO max_cap FROM routes WHERE id = NEW.route_id;
    IF NEW.total_seats > max_cap THEN
        RAISE EXCEPTION 'Slot total_seats (%) exceeds Route capacity_cap (%)', NEW.total_seats, max_cap;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_slot_total_seats
BEFORE INSERT OR UPDATE OF total_seats, route_id ON slots
FOR EACH ROW EXECUTE FUNCTION check_slot_total_seats();

-- B: Auto-update free seats and boards on Slot when Booking is inserted/updated (Transaction integrity)
CREATE OR REPLACE FUNCTION update_slot_on_booking()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle new active bookings
    IF (TG_OP = 'INSERT') THEN
        IF NEW.status = 'active' THEN
            -- Check if slot has enough seats and rental boards
            IF (SELECT free_seats FROM slots WHERE id = NEW.slot_id) < NEW.seats_count THEN
                RAISE EXCEPTION 'Not enough free seats on this slot';
            END IF;
            IF (SELECT free_rental_boards FROM slots WHERE id = NEW.slot_id) < NEW.rental_count THEN
                RAISE EXCEPTION 'Not enough free rental boards on this slot';
            END IF;

            UPDATE slots 
            SET free_seats = free_seats - NEW.seats_count,
                free_rental_boards = free_rental_boards - NEW.rental_count
            WHERE id = NEW.slot_id;
        END IF;
    
    -- Handle changes to booking status (e.g., cancellations)
    ELSIF (TG_OP = 'UPDATE') THEN
        -- From active to cancelled (early cancellation) -> return seats and boards
        IF OLD.status = 'active' AND NEW.status = 'cancelled' THEN
            UPDATE slots 
            SET free_seats = free_seats + OLD.seats_count,
                free_rental_boards = free_rental_boards + OLD.rental_count
            WHERE id = OLD.slot_id;
        
        -- From active to late_cancel -> seats and boards are NOT returned (Domain constraint)
        ELSIF OLD.status = 'active' AND NEW.status = 'late_cancel' THEN
            -- No changes to slot availability (seats/boards are lost to other clients)
            NULL;
        
        -- From active to club_cancelled -> slot is cancelled, no need to update seats (slot is disabled anyway)
        ELSIF OLD.status = 'active' AND NEW.status = 'club_cancelled' THEN
            NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_slot_on_booking
AFTER INSERT OR UPDATE OF status ON bookings
FOR EACH ROW EXECUTE FUNCTION update_slot_on_booking();

-- C: Auto-update average rating on Instructor when a new rating is inserted
CREATE OR REPLACE FUNCTION update_instructor_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE instructors
    SET rating = (
        SELECT COALESCE(AVG(rating), 5.00)::NUMERIC(3,2)
        FROM ratings
        WHERE instructor_id = NEW.instructor_id
    )
    WHERE id = NEW.instructor_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_instructor_rating
AFTER INSERT ON ratings
FOR EACH ROW EXECUTE FUNCTION update_instructor_rating();

-- 8. Recommended Indexes for performance (Mobile App usage patterns)
CREATE INDEX idx_slots_start_at ON slots(start_at) WHERE status = 'scheduled';
CREATE INDEX idx_bookings_client_id ON bookings(client_id);
CREATE INDEX idx_bookings_slot_id ON bookings(slot_id);

-- 9. Seed Mock Data
-- Seed Routes
INSERT INTO routes (id, name, description, type, capacity_cap, duration_min, geometry) VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Озеро Кабан (Новичок)', 'Увлекательная прогулка по озеру Кабан для начинающих.', 'novice', 8, 60, 'encoded_geom_novice'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Голубые Озера (Профи)', 'Маршрут повышенной сложности для опытных сапбордистов.', 'experienced', 12, 90, 'encoded_geom_exp')
ON CONFLICT (id) DO NOTHING;

-- Seed Instructors
INSERT INTO instructors (id, name) VALUES
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'Алексей'),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'Данил'),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b33', 'Ирина')
ON CONFLICT (id) DO NOTHING;

-- Seed Slots (using dynamic dates so they are always in the upcoming week)
INSERT INTO slots (id, route_id, instructor_id, start_at, total_seats, free_seats, free_rental_boards, price, rental_price, meeting_point, meeting_point_lat, meeting_point_lng, status) VALUES
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', NOW() + INTERVAL '1 day', 8, 8, 8, 1500.00, 500.00, 'Набережная озера Кабан', 55.7724, 49.1234, 'scheduled'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', NOW() + INTERVAL '2 days', 6, 6, 6, 1500.00, 500.00, 'Набережная озера Кабан', 55.7724, 49.1234, 'scheduled'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b33', NOW() + INTERVAL '3 days', 10, 10, 10, 2500.00, 700.00, 'Вход на Голубые Озера', 55.9012, 49.1567, 'scheduled'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', NOW() + INTERVAL '4 days', 12, 12, 12, 2500.00, 700.00, 'Вход на Голубые Озера', 55.9012, 49.1567, 'scheduled'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', NOW() + INTERVAL '5 days', 8, 8, 8, 1800.00, 500.00, 'Набережная озера Кабан', 55.7724, 49.1234, 'scheduled')
ON CONFLICT (id) DO NOTHING;

