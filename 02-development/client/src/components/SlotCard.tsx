import type { Slot } from '../api/types';
import { formatDateTime, trackLabel } from '../utils';

export function SlotCard({ slot, onClick }: { slot: Slot; onClick: () => void }) {
  const isFull = slot.available_karts <= 0;
  const isCancelled = slot.status === 'CANCELLED_BY_WEATHER';
  const disabled = isFull || isCancelled;

  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`w-full rounded-2xl border p-4 text-left transition active:scale-[0.99] ${
        disabled
          ? 'border-slate-200 bg-slate-50 opacity-60'
          : 'border-slate-200 bg-white shadow-sm hover:border-slate-300'
      }`}
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="font-semibold text-slate-900">{formatDateTime(slot.start_time)}</p>
          <p className="mt-0.5 text-sm text-slate-500">{trackLabel(slot.track_config)}</p>
        </div>
        {isCancelled ? (
          <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-800">
            Отменён (погода)
          </span>
        ) : (
          <span
            className={`rounded-full px-2.5 py-1 text-xs font-medium ${
              isFull
                ? 'bg-slate-200 text-slate-600'
                : slot.available_karts <= 2
                  ? 'bg-amber-100 text-amber-800'
                  : 'bg-emerald-100 text-emerald-700'
            }`}
          >
            {isFull ? 'Мест нет' : `Осталось ${slot.available_karts} из ${slot.max_karts}`}
          </span>
        )}
      </div>
      <div className="mt-3 flex items-center gap-2 text-sm text-slate-600">
        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-slate-100 text-xs">
          🏁
        </span>
        <span>{slot.marshal.name}</span>
        <span className="text-amber-500">★ {slot.marshal.rating.toFixed(1)}</span>
      </div>
    </button>
  );
}
