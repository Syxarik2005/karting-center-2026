import type { Booking, ClientProfile, GearType, Slot } from './types';
import { ApiError } from './types';
import { slots as seedSlots, initialBookings, clientProfile } from './mockData';

// -----------------------------------------------------------------------
// This module stands in for the real backend (which is explicitly out of
// scope — see 01-analysis/0-customer-brief/customer-brief.md, R-004).
// It reproduces the contract in 01-analysis/api/openapi.yaml as closely as
// possible: same shapes, same status codes, same error codes, including a
// simulated 409 for "someone else booked the last kart first" so the UI's
// conflict-handling path (BR-01) is exercised even without a real server.
// -----------------------------------------------------------------------

const DELAY_MS = 450;

// Cancellation cutoff. The customer brief flags a same-day cancellation as
// "a problem" but doesn't give an exact number (see domain-description.md,
// open question #1). We assume 60 minutes as a safe placeholder — this is
// called out explicitly in 02-development/features/FEAT-003-my-bookings-cancel.md
// as an assumption to confirm with Denis, not a hidden decision.
export const CANCEL_CUTOFF_MINUTES = 60;

function delay<T>(value: T): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), DELAY_MS));
}

// In-memory "database" for this session.
let slotsDb: Slot[] = seedSlots.map((s) => ({ ...s }));
let bookingsDb: Booking[] = initialBookings.map((b) => ({ ...b }));

// Exposed purely for test isolation — each test case should start from a
// known, deterministic state instead of leaking mutations between tests.
export function resetMockDb(): void {
  slotsDb = seedSlots.map((s) => ({ ...s }));
  bookingsDb = initialBookings.map((b) => ({ ...b }));
}

function findSlot(slotId: string): Slot | undefined {
  return slotsDb.find((s) => s.id === slotId);
}

function cloneSlot(slot: Slot): Slot {
  // A real HTTP response is a fresh, independent object every time (JSON in,
  // JSON out) — the caller can hold onto it and it will never silently
  // change under them. This mock previously returned the live in-memory
  // object instead, so a "before" snapshot taken by a caller would mutate
  // into the "after" state the instant createBooking/cancelBooking touched
  // the same slot, since both were the same reference. See BUG-001.
  return { ...slot, marshal: { ...slot.marshal } };
}

function cloneBooking(booking: Booking): Booking {
  return { ...booking, slot: cloneSlot(booking.slot) };
}

export async function getSlots(params: {
  dateFrom?: string;
  dateTo?: string;
  trackConfig?: 'SHORT' | 'LONG';
}): Promise<Slot[]> {
  const from = params.dateFrom ? new Date(params.dateFrom) : new Date();
  const to = params.dateTo
    ? new Date(params.dateTo)
    : new Date(from.getTime() + 7 * 24 * 60 * 60 * 1000); // R-027 default: 7 days

  const result = slotsDb.filter((s) => {
    const t = new Date(s.start_time);
    const inRange = t >= from && t <= to;
    const matchesTrack = !params.trackConfig || s.track_config === params.trackConfig;
    return inRange && matchesTrack;
  });

  return delay(result.sort((a, b) => a.start_time.localeCompare(b.start_time)).map(cloneSlot));
}

export async function getSlot(slotId: string): Promise<Slot> {
  const slot = findSlot(slotId);
  if (!slot) {
    throw new ApiError(404, { code: 'NOT_FOUND', message: 'Слот не найден' });
  }
  return delay(cloneSlot(slot));
}

export async function createBooking(input: {
  slotId: string;
  gearType: GearType;
}): Promise<Booking> {
  await delay(null);
  const slot = findSlot(input.slotId);

  if (!slot) {
    throw new ApiError(410, {
      code: 'SLOT_GONE',
      message: 'Заезд больше недоступен',
    });
  }
  if (slot.status !== 'SCHEDULED') {
    throw new ApiError(410, {
      code: 'SLOT_GONE',
      message: 'Заезд отменён и недоступен для записи',
    });
  }
  if (slot.available_karts <= 0) {
    throw new ApiError(409, {
      code: 'NO_KARTS_AVAILABLE',
      message: 'Места на этот заезд закончились',
    });
  }

  slot.available_karts -= 1;
  const booking: Booking = {
    id: `booking-${Date.now()}`,
    slot: cloneSlot(slot),
    status: 'ACTIVE',
    gear_type: input.gearType,
  };
  bookingsDb = [booking, ...bookingsDb];
  return cloneBooking(booking);
}

export async function getMyBookings(): Promise<Booking[]> {
  return delay(
    [...bookingsDb]
      .sort((a, b) => b.slot.start_time.localeCompare(a.slot.start_time))
      .map(cloneBooking),
  );
}

export async function getBooking(bookingId: string): Promise<Booking> {
  const booking = bookingsDb.find((b) => b.id === bookingId);
  if (!booking) {
    throw new ApiError(404, { code: 'NOT_FOUND', message: 'Бронирование не найдено' });
  }
  return delay(cloneBooking(booking));
}

export async function cancelBooking(bookingId: string): Promise<Booking> {
  await delay(null);
  const booking = bookingsDb.find((b) => b.id === bookingId);
  if (!booking) {
    throw new ApiError(404, { code: 'NOT_FOUND', message: 'Бронирование не найдено' });
  }

  const minutesToStart =
    (new Date(booking.slot.start_time).getTime() - Date.now()) / 60000;

  if (minutesToStart < CANCEL_CUTOFF_MINUTES) {
    throw new ApiError(400, {
      code: 'CANCEL_TOO_LATE',
      message: `Отмена невозможна менее чем за ${CANCEL_CUTOFF_MINUTES} минут до старта`,
    });
  }

  booking.status = 'CANCELLED_BY_CLIENT';
  // Cancelling frees the kart back up (mirrors backend atomic-availability rule, BR-01).
  const slot = findSlot(booking.slot.id);
  if (slot) slot.available_karts += 1;

  return cloneBooking(booking);
}

export async function rateMarshal(
  bookingId: string,
  rating: number,
  comment?: string,
): Promise<void> {
  await delay(null);
  const booking = bookingsDb.find((b) => b.id === bookingId);
  if (!booking) {
    throw new ApiError(404, { code: 'NOT_FOUND', message: 'Бронирование не найдено' });
  }
  booking.client_rating = rating;
  void comment; // stored server-side only in the real system; not surfaced back to the client
}

export async function getProfile(): Promise<ClientProfile> {
  return delay(clientProfile);
}
