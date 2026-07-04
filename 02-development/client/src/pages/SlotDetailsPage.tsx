import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createBooking, getSlot } from '../api/mockApi';
import { ApiError } from '../api/types';
import type { GearType } from '../api/types';
import { Skeleton, ErrorState } from '../components/States';
import { formatDateTime, trackLabel } from '../utils';

export function SlotDetailsPage() {
  const { slotId } = useParams<{ slotId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [gear, setGear] = useState<GearType>('OWN');
  const [conflictMessage, setConflictMessage] = useState<string | null>(null);

  const {
    data: slot,
    isLoading,
    isError,
  } = useQuery({
    queryKey: ['slot', slotId],
    queryFn: () => getSlot(slotId!),
    enabled: !!slotId,
  });

  const mutation = useMutation({
    mutationFn: () => createBooking({ slotId: slotId!, gearType: gear }),
    onSuccess: (booking) => {
      queryClient.invalidateQueries({ queryKey: ['slots'] });
      queryClient.invalidateQueries({ queryKey: ['bookings'] });
      navigate(`/bookings/${booking.id}`, { state: { justBooked: true } });
    },
    onError: (err: unknown) => {
      if (err instanceof ApiError) {
        if (err.code === 'NO_KARTS_AVAILABLE') {
          setConflictMessage('Места на этот заезд закончились — кто-то забронировал раньше.');
        } else if (err.code === 'SLOT_GONE') {
          setConflictMessage('Заезд больше недоступен для записи.');
        } else {
          setConflictMessage(err.message);
        }
        // Re-sync slot state so the UI reflects reality (e.g. available_karts hit 0).
        queryClient.invalidateQueries({ queryKey: ['slot', slotId] });
        queryClient.invalidateQueries({ queryKey: ['slots'] });
      }
    },
  });

  if (isLoading) {
    return (
      <div className="px-4 pt-6">
        <Skeleton rows={2} />
      </div>
    );
  }
  if (isError || !slot) {
    return (
      <div className="px-4 pt-6">
        <ErrorState message="Не удалось загрузить заезд" />
      </div>
    );
  }

  const isFull = slot.available_karts <= 0;
  const isCancelled = slot.status !== 'SCHEDULED';

  return (
    <div className="px-4 pb-28 pt-6">
      <button onClick={() => navigate(-1)} className="text-sm text-slate-500">
        ← Назад
      </button>

      <h1 className="mt-3 text-xl font-bold text-slate-900">{formatDateTime(slot.start_time)}</h1>
      <p className="mt-1 text-slate-600">{trackLabel(slot.track_config)}</p>

      <div className="mt-4 space-y-3 rounded-2xl border border-slate-200 bg-white p-4">
        <Row label="Маршал" value={`${slot.marshal.name} · ★ ${slot.marshal.rating.toFixed(1)}`} />
        <Row
          label="Свободно карт"
          value={isFull ? 'Мест нет' : `${slot.available_karts} из ${slot.max_karts}`}
        />
        <Row label="Место сбора" value={slot.gathering_place} />
        <Row label="Прокат экипировки" value={`${slot.rental_tariff} ₽`} />
      </div>

      {isCancelled && (
        <div className="mt-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-800">
          Этот заезд отменён и недоступен для записи.
        </div>
      )}

      {!isCancelled && (
        <>
          <h2 className="mt-6 text-sm font-semibold text-slate-700">Экипировка</h2>
          <div className="mt-2 space-y-2">
            <GearOption
              selected={gear === 'OWN'}
              title="Своя экипировка"
              subtitle="Шлем и подшлемник"
              onClick={() => setGear('OWN')}
            />
            <GearOption
              selected={gear === 'RENTAL'}
              title="Взять в прокат"
              subtitle={`${slot.rental_tariff} ₽ · оплата на месте`}
              onClick={() => setGear('RENTAL')}
            />
          </div>
        </>
      )}

      {conflictMessage && (
        <div className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-700">
          {conflictMessage}
        </div>
      )}

      {!isCancelled && (
        <div className="fixed inset-x-0 bottom-0 border-t border-slate-200 bg-white p-4">
          <button
            disabled={isFull || mutation.isPending}
            onClick={() => {
              setConflictMessage(null);
              mutation.mutate();
            }}
            className="mx-auto block w-full max-w-md rounded-xl bg-slate-900 py-3 font-medium text-white disabled:opacity-40"
          >
            {mutation.isPending ? 'Отправляем…' : isFull ? 'Мест нет' : 'Записаться'}
          </button>
        </div>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-slate-500">{label}</span>
      <span className="font-medium text-slate-900">{value}</span>
    </div>
  );
}

function GearOption({
  selected,
  title,
  subtitle,
  onClick,
}: {
  selected: boolean;
  title: string;
  subtitle: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`w-full rounded-2xl border p-4 text-left ${
        selected ? 'border-slate-900 bg-slate-50' : 'border-slate-200 bg-white'
      }`}
    >
      <div className="flex items-center justify-between">
        <div>
          <p className="font-medium text-slate-900">{title}</p>
          <p className="text-sm text-slate-500">{subtitle}</p>
        </div>
        <span
          className={`flex h-5 w-5 items-center justify-center rounded-full border-2 ${
            selected ? 'border-slate-900 bg-slate-900' : 'border-slate-300'
          }`}
        >
          {selected && <span className="h-2 w-2 rounded-full bg-white" />}
        </span>
      </div>
    </button>
  );
}
