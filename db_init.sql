-- PostgreSQL Database Initialization Migration for "Apex" Karting Center
--
-- NOTE: this schema was rewritten from scratch to match 01-analysis/api/openapi.yaml
-- and 01-analysis/1-elicitation/domain-description.md — an earlier draft of this
-- file was a verbatim copy of the reference "Volna" SUP-boarding-club schema
-- (routes/lakes/rental boards) and did not describe this domain at all.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Enums (names/values mirror openapi.yaml components.schemas exactly)
CREATE TYPE track_config AS ENUM ('SHORT', 'LONG');
CREATE TYPE gear_type AS ENUM ('OWN', 'RENTAL');
CREATE TYPE slot_status AS ENUM ('SCHEDULED', 'CANCELLED_BY_WEATHER', 'COMPLETED');
CREATE TYPE booking_status AS ENUM ('ACTIVE', 'CANCELLED_BY_CLIENT', 'CANCELLED_BY_CENTER', 'COMPLETED');

-- 2. Table: clients
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    is_regular BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Table: marshals (маршалы — provided by the center, not created via the client app)
CREATE TABLE marshals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    avatar_url TEXT NOT NULL DEFAULT '',
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.00
);

-- 4. Table: slots
-- Track config lives directly on the slot (R-015 / screen-registry.md) — there is
-- no separate "routes" catalog in this domain, unlike the Volna reference project.
CREATE TABLE slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    marshal_id UUID NOT NULL REFERENCES marshals(id) ON DELETE RESTRICT,
    start_time TIMESTAMPTZ NOT NULL,
    track_config track_config NOT NULL,
    max_karts INT NOT NULL CHECK (max_karts > 0 AND max_karts <= 14), -- BR: 14 karts max at Apex
    available_karts INT NOT NULL,
    rental_tariff INT NOT NULL CHECK (rental_tariff >= 0), -- RUB, gear rental price (R-015)
    gathering_place TEXT NOT NULL,
    status slot_status NOT NULL DEFAULT 'SCHEDULED',

    CONSTRAINT chk_available_karts_range CHECK (available_karts >= 0 AND available_karts <= max_karts)
);

-- 5. Table: bookings
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slot_id UUID NOT NULL REFERENCES slots(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    gear_type gear_type NOT NULL,
    status booking_status NOT NULL DEFAULT 'ACTIVE',
    cancellation_reason TEXT, -- set only when status = CANCELLED_BY_CENTER (openapi.yaml)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cancelled_at TIMESTAMPTZ
);

-- 6. Table: ratings (one per booking — a completed ride can be rated once)
CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID UNIQUE NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    marshal_id UUID NOT NULL REFERENCES marshals(id) ON DELETE RESTRICT,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Triggers enforcing BR-01 (atomic kart availability) and BR-02 (center cancellations)

-- A: when a booking is created ACTIVE, atomically claim one kart on its slot.
-- Raising an exception here is what makes "the last kart" conflict (409 in the
-- API layer) safe under concurrent requests — the DB, not the application code,
-- is the single source of truth for availability.
CREATE OR REPLACE FUNCTION claim_kart_on_booking()
RETURNS TRIGGER AS $$
DECLARE
    remaining INT;
    slot_state slot_status;
BEGIN
    IF NEW.status = 'ACTIVE' THEN
        SELECT available_karts, status INTO remaining, slot_state
        FROM slots WHERE id = NEW.slot_id FOR UPDATE;

        IF slot_state IS DISTINCT FROM 'SCHEDULED' THEN
            RAISE EXCEPTION 'SLOT_GONE: slot % is not open for booking', NEW.slot_id;
        END IF;
        IF remaining <= 0 THEN
            RAISE EXCEPTION 'NO_KARTS_AVAILABLE: slot % has no free karts', NEW.slot_id;
        END IF;

        UPDATE slots SET available_karts = available_karts - 1 WHERE id = NEW.slot_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_claim_kart_on_booking
BEFORE INSERT ON bookings
FOR EACH ROW EXECUTE FUNCTION claim_kart_on_booking();

-- B: releasing a kart when a client cancels in time (CANCELLED_BY_CLIENT).
-- A center cancellation (CANCELLED_BY_CENTER) does not release a kart back into
-- circulation on this slot — the whole slot is effectively dead once the center
-- cancels it (BR-02) — so no availability change is made in that branch.
CREATE OR REPLACE FUNCTION release_kart_on_cancel()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'ACTIVE' AND NEW.status = 'CANCELLED_BY_CLIENT' THEN
        UPDATE slots SET available_karts = available_karts + 1 WHERE id = OLD.slot_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_release_kart_on_cancel
AFTER UPDATE OF status ON bookings
FOR EACH ROW EXECUTE FUNCTION release_kart_on_cancel();

-- C: keep marshal.rating as a running average of their ratings.
CREATE OR REPLACE FUNCTION update_marshal_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE marshals
    SET rating = (
        SELECT COALESCE(AVG(rating), 5.00)::NUMERIC(3,2)
        FROM ratings
        WHERE marshal_id = NEW.marshal_id
    )
    WHERE id = NEW.marshal_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_marshal_rating
AFTER INSERT ON ratings
FOR EACH ROW EXECUTE FUNCTION update_marshal_rating();

-- 8. Indexes
CREATE INDEX idx_slots_start_time ON slots(start_time) WHERE status = 'SCHEDULED';
CREATE INDEX idx_bookings_client_id ON bookings(client_id);
CREATE INDEX idx_bookings_slot_id ON bookings(slot_id);

-- 9. Seed data — картинг-центр «Апекс» (see 01-analysis/0-customer-brief)
INSERT INTO marshals (id, name, avatar_url, rating) VALUES
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'Игорь Соколов', '', 4.90),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'Дарья Волкова', '', 4.80),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b33', 'Максим Орлов', '', 4.60),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b44', 'Настя Кузнецова', '', 4.30),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b55', 'Пётр Гринько', '', 4.70)
ON CONFLICT (id) DO NOTHING;

-- Seed slots (dynamic dates so the schedule always shows a real upcoming week)
INSERT INTO slots (id, marshal_id, start_time, track_config, max_karts, available_karts, rental_tariff, gathering_place, status) VALUES
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', NOW() + INTERVAL '3 hours', 'SHORT', 8, 5, 400, 'Картинг-центр «Апекс», стойка регистрации', 'SCHEDULED'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c22', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', NOW() + INTERVAL '6 hours', 'LONG', 14, 1, 400, 'Картинг-центр «Апекс», стойка регистрации', 'SCHEDULED'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b33', NOW() + INTERVAL '9 hours', 'LONG', 14, 0, 450, 'Картинг-центр «Апекс», стойка регистрации', 'SCHEDULED'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b44', NOW() + INTERVAL '27 hours', 'SHORT', 8, 8, 400, 'Картинг-центр «Апекс», стойка регистрации', 'SCHEDULED'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b55', NOW() + INTERVAL '30 hours', 'LONG', 14, 6, 450, 'Картинг-центр «Апекс», стойка регистрации', 'CANCELLED_BY_WEATHER'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', NOW() + INTERVAL '75 hours', 'SHORT', 8, 4, 400, 'Картинг-центр «Апекс», стойка регистрации', 'SCHEDULED')
ON CONFLICT (id) DO NOTHING;
