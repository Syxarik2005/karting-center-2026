import type { Booking } from '../api/types';
import { bookingStatusLabel, formatDateTime, trackLabel } from '../utils';

export function BookingCard({ booking, onClick }: { booking: Booking; onClick: () => void }) {
  const status = bookingStatusLabel(booking.status);
  return (
    <button
      onClick={onClick}
      className="w-full rounded-2xl border border-slate-200 bg-white p-4 text-left shadow-sm transition active:scale-[0.99]"
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="font-semibold text-slate-900">
            {formatDateTime(booking.slot.start_time)}
          </p>
          <p className="mt-0.5 text-sm text-slate-500">
            {trackLabel(booking.slot.track_config)} · {booking.slot.marshal.name}
          </p>
        </div>
        <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${status.tone}`}>
          {status.label}
        </span>
      </div>
      {booking.status === 'CANCELLED_BY_CENTER' && booking.cancellation_reason && (
        <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
          Причина: {booking.cancellation_reason}
        </p>
      )}
    </button>
  );
}
