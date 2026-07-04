import type { Marshal, Slot, Booking, ClientProfile } from './types';

// --- Marshals (5 regulars, per customer brief) ---
export const marshals: Marshal[] = [
  { id: 'm-1', name: 'Игорь Соколов', avatar_url: '', rating: 4.9 },
  { id: 'm-2', name: 'Дарья Волкова', avatar_url: '', rating: 4.8 },
  { id: 'm-3', name: 'Максим Орлов', avatar_url: '', rating: 4.6 },
  { id: 'm-4', name: 'Настя Кузнецова', avatar_url: '', rating: 4.3 },
  { id: 'm-5', name: 'Пётр Гринько', avatar_url: '', rating: 4.7 },
];

function hoursFromNow(h: number): Date {
  const d = new Date();
  d.setMinutes(0, 0, 0);
  d.setHours(d.getHours() + h);
  return d;
}

// A spread of slots across the next ~9 days so the 7-day default horizon
// and the "load more / pick a later date" filter both have something to show.
export const slots: Slot[] = [
  {
    id: 'slot-1',
    start_time: hoursFromNow(3).toISOString(),
    track_config: 'SHORT',
    marshal: marshals[0],
    available_karts: 5,
    max_karts: 8,
    status: 'SCHEDULED',
    rental_tariff: 400,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-2',
    start_time: hoursFromNow(6).toISOString(),
    track_config: 'LONG',
    marshal: marshals[1],
    available_karts: 1,
    max_karts: 14,
    status: 'SCHEDULED',
    rental_tariff: 400,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-3',
    start_time: hoursFromNow(9).toISOString(),
    track_config: 'LONG',
    marshal: marshals[2],
    available_karts: 0,
    max_karts: 14,
    status: 'SCHEDULED',
    rental_tariff: 450,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-4',
    start_time: hoursFromNow(27).toISOString(),
    track_config: 'SHORT',
    marshal: marshals[3],
    available_karts: 8,
    max_karts: 8,
    status: 'SCHEDULED',
    rental_tariff: 400,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-5',
    start_time: hoursFromNow(30).toISOString(),
    track_config: 'LONG',
    marshal: marshals[4],
    available_karts: 6,
    max_karts: 14,
    status: 'CANCELLED_BY_WEATHER',
    rental_tariff: 450,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-6',
    start_time: hoursFromNow(75).toISOString(),
    track_config: 'SHORT',
    marshal: marshals[0],
    available_karts: 4,
    max_karts: 8,
    status: 'SCHEDULED',
    rental_tariff: 400,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-7',
    start_time: hoursFromNow(150).toISOString(),
    track_config: 'LONG',
    marshal: marshals[1],
    available_karts: 10,
    max_karts: 14,
    status: 'SCHEDULED',
    rental_tariff: 450,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    id: 'slot-8',
    start_time: hoursFromNow(220).toISOString(), // >7 days out — only visible via date filter
    track_config: 'LONG',
    marshal: marshals[2],
    available_karts: 14,
    max_karts: 14,
    status: 'SCHEDULED',
    rental_tariff: 450,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
  {
    // Starts very soon — exists specifically to make the cancellation
    // cutoff (see mockApi.ts CANCEL_CUTOFF_MINUTES) testable without
    // reaching into private state from a test.
    id: 'slot-9-near-term',
    start_time: (() => {
      const d = new Date();
      d.setMinutes(d.getMinutes() + 10);
      return d.toISOString();
    })(),
    track_config: 'SHORT',
    marshal: marshals[0],
    available_karts: 8,
    max_karts: 8,
    status: 'SCHEDULED',
    rental_tariff: 400,
    gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
  },
];

export const initialBookings: Booking[] = [
  {
    id: 'booking-1',
    slot: {
      ...slots[4], // the weather-cancelled slot
    },
    status: 'CANCELLED_BY_CENTER',
    gear_type: 'RENTAL',
    cancellation_reason: 'Отмена из-за гололёда на трассе',
  },
  {
    id: 'booking-2',
    slot: {
      id: 'slot-past-1',
      start_time: (() => {
        const d = new Date();
        d.setDate(d.getDate() - 3);
        return d.toISOString();
      })(),
      track_config: 'SHORT',
      marshal: marshals[0],
      available_karts: 0,
      max_karts: 8,
      status: 'COMPLETED',
      rental_tariff: 400,
      gathering_place: 'Картинг-центр «Апекс», стойка регистрации',
    },
    status: 'COMPLETED',
    gear_type: 'OWN',
  },
];

export const clientProfile: ClientProfile = {
  id: 'client-1',
  name: 'Алекс',
  phone: '+7 900 123-45-67',
  is_regular: true,
};
