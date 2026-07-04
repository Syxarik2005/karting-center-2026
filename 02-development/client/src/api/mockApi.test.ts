import { beforeEach, describe, expect, it } from 'vitest';
import {
  cancelBooking,
  createBooking,
  getMyBookings,
  getSlots,
  rateMarshal,
  resetMockDb,
} from './mockApi';
import { ApiError } from './types';

beforeEach(() => {
  resetMockDb();
});

describe('getSlots (BR-03: default 7-day horizon)', () => {
  it('excludes slots more than 7 days out by default', async () => {
    const result = await getSlots({});
    expect(result.find((s) => s.id === 'slot-8')).toBeUndefined();
  });

  it('includes far-out slots when an explicit longer range is requested', async () => {
    const dateTo = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const result = await getSlots({ dateTo });
    expect(result.find((s) => s.id === 'slot-8')).toBeDefined();
  });

  it('filters by track configuration', async () => {
    const dateTo = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const result = await getSlots({ dateTo, trackConfig: 'SHORT' });
    expect(result.every((s) => s.track_config === 'SHORT')).toBe(true);
  });
});

describe('createBooking (BR-01: atomic availability)', () => {
  it('succeeds and decrements available_karts', async () => {
    const before = (await getSlots({})).find((s) => s.id === 'slot-1')!;
    const booking = await createBooking({ slotId: 'slot-1', gearType: 'OWN' });
    const after = (await getSlots({})).find((s) => s.id === 'slot-1')!;

    expect(booking.status).toBe('ACTIVE');
    expect(after.available_karts).toBe(before.available_karts - 1);
  });

  it('throws 409 NO_KARTS_AVAILABLE when the slot is full', async () => {
    await expect(createBooking({ slotId: 'slot-3', gearType: 'OWN' })).rejects.toMatchObject({
      status: 409,
      code: 'NO_KARTS_AVAILABLE',
    });
  });

  it('throws 410 SLOT_GONE for a weather-cancelled slot', async () => {
    await expect(createBooking({ slotId: 'slot-5', gearType: 'OWN' })).rejects.toMatchObject({
      status: 410,
      code: 'SLOT_GONE',
    });
  });

  it('throws 410 SLOT_GONE for a non-existent slot id', async () => {
    await expect(
      createBooking({ slotId: 'does-not-exist', gearType: 'OWN' }),
    ).rejects.toMatchObject({ status: 410 });
  });
});

describe('cancelBooking (cancellation cutoff + kart release)', () => {
  it('rejects cancellation inside the cutoff window with a 400', async () => {
    const booking = await createBooking({ slotId: 'slot-9-near-term', gearType: 'OWN' });
    await expect(cancelBooking(booking.id)).rejects.toMatchObject({
      status: 400,
      code: 'CANCEL_TOO_LATE',
    });
  });

  it('allows cancellation well outside the cutoff and releases the kart', async () => {
    const before = (await getSlots({})).find((s) => s.id === 'slot-1')!;
    const booking = await createBooking({ slotId: 'slot-1', gearType: 'OWN' });
    const cancelled = await cancelBooking(booking.id);
    const after = (await getSlots({})).find((s) => s.id === 'slot-1')!;

    expect(cancelled.status).toBe('CANCELLED_BY_CLIENT');
    expect(after.available_karts).toBe(before.available_karts);
  });

  it('throws 404 for an unknown booking id', async () => {
    await expect(cancelBooking('nope')).rejects.toMatchObject({ status: 404 });
  });
});

describe('BR-02: bookings cancelled by the center', () => {
  it('keeps CANCELLED_BY_CENTER bookings visible with their reason', async () => {
    const bookings = await getMyBookings();
    const centerCancelled = bookings.find((b) => b.id === 'booking-1');
    expect(centerCancelled?.status).toBe('CANCELLED_BY_CENTER');
    expect(centerCancelled?.cancellation_reason).toBeTruthy();
  });
});

describe('rateMarshal', () => {
  it('records a rating against the booking', async () => {
    await rateMarshal('booking-2', 5, 'Отличный инструктаж');
    const bookings = await getMyBookings();
    const rated = bookings.find((b) => b.id === 'booking-2');
    expect(rated?.client_rating).toBe(5);
  });

  it('throws 404 for an unknown booking id', async () => {
    await expect(rateMarshal('nope', 5)).rejects.toBeInstanceOf(ApiError);
  });
});
