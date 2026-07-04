// Types mirror 01-analysis/api/openapi.yaml exactly.
// Client app must not invent fields the backend contract doesn't provide (R-015).

export type TrackConfig = 'SHORT' | 'LONG';
export type GearType = 'OWN' | 'RENTAL';
export type BookingStatus =
  | 'ACTIVE'
  | 'CANCELLED_BY_CLIENT'
  | 'CANCELLED_BY_CENTER'
  | 'COMPLETED';
export type SlotStatus = 'SCHEDULED' | 'CANCELLED_BY_WEATHER' | 'COMPLETED';

export interface Marshal {
  id: string;
  name: string;
  avatar_url: string;
  rating: number;
}

export interface Slot {
  id: string;
  start_time: string; // ISO date-time
  track_config: TrackConfig;
  marshal: Marshal;
  available_karts: number;
  max_karts: number;
  status: SlotStatus;
  rental_tariff: number; // RUB
  gathering_place: string;
}

export interface Booking {
  id: string;
  slot: Slot;
  status: BookingStatus;
  gear_type: GearType;
  cancellation_reason?: string;
  client_rating?: number; // client-side convenience flag: has this booking been rated already
}

export interface ClientProfile {
  id: string;
  name: string;
  phone: string;
  is_regular: boolean;
}

export interface ErrorResponse {
  code: string;
  message: string;
}

export class ApiError extends Error {
  code: string;
  status: number;
  constructor(status: number, body: ErrorResponse) {
    super(body.message);
    this.code = body.code;
    this.status = status;
  }
}
