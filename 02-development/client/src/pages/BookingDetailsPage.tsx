import { useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { cancelBooking, getBooking, CANCEL_CUTOFF_MINUTES } from '../api/mockApi';
import { ApiError } from '../api/types';
import { Skeleton, ErrorState } from '../components/States';
import { bookingStatusLabel, formatDateTime, trackLabel } from '../utils';

export function BookingDetailsPage() {
  const { bookingId } = useParams<{ bookingId: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();
  const [confirmingCancel, setConfirmingCancel] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const justBooked = (location.state as { justBooked?: boolean } | null)?.justBooked;

  const { data: booking, isLoading, isError } = useQuery({
    queryKey: ['booking', bookingId],
    queryFn: () => getBooking(bookingId!),
    enabled: !!bookingId,
  });

  const cancelMutation = useMutation({
    mutationFn: () => cancelBooking(bookingId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['booking', bookingId] });
      queryClient.invalidateQueries({ queryKey: ['bookings'] });
      queryClient.invalidateQueries({ queryKey: ['slots'] });
      setConfirmingCancel(false);
    },
    onError: (err: unknown) => {
      if (err instanceof ApiError) setCancelError(err.message);
      setConfirmingCancel(false);
    },
  });

  if (isLoading) {
    return (
      <div className="px-4 pt-6">
        <Skeleton rows={1} />
      </div>
    );
  }
  if (isError || !booking) {
    return (
      <div className="px-4 pt-6">
        <ErrorState message="Не удалось загрузить бронирование" />
      </div>
    );
  }

  const status = bookingStatusLabel(booking.status);
  const canRate = booking.status === 'COMPLETED' && !booking.client_rating;

  return (
    <div className="px-4 pb-24 pt-6">
      <button onClick={() => navigate(-1)} className="text-sm text-slate-500">
        ← Назад
      </button>

      {justBooked && (
        <div className="mt-3 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-800">
          ✅ Вы записаны! Увидимся на трассе.
        </div>
      )}

      <div className="mt-3 flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">
          {formatDateTime(booking.slot.start_time)}
        </h1>
        <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${status.tone}`}>
          {status.label}
        </span>
      </div>

      <div className="mt-4 space-y-3 rounded-2xl border border-slate-200 bg-white p-4">
        <Row label="Трасса" value={trackLabel(booking.slot.track_config)} />
        <Row label="Маршал" value={booking.slot.marshal.name} />
        <Row label="Экипировка" value={booking.gear_type === 'OWN' ? 'Своя' : 'Прокат'} />
        <Row label="Место сбора" value={booking.slot.gathering_place} />
      </div>

      {booking.status === 'CANCELLED_BY_CENTER' && booking.cancellation_reason && (
        <div className="mt-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-800">
          Причина отмены: {booking.cancellation_reason}. Повторная запись на этот заезд
          недоступна — выберите другой в расписании.
        </div>
      )}

      {cancelError && (
        <div className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-700">{cancelError}</div>
      )}

      {booking.status === 'ACTIVE' && !confirmingCancel && (
        <button
          onClick={() => setConfirmingCancel(true)}
          className="mt-6 w-full rounded-xl border border-red-200 py-3 text-sm font-medium text-red-600"
        >
          Отменить запись
        </button>
      )}

      {confirmingCancel && (
        <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-700">
            Отмена доступна не позднее чем за {CANCEL_CUTOFF_MINUTES} минут до старта. Точно
            отменить запись?
          </p>
          <div className="mt-3 flex gap-2">
            <button
              onClick={() => setConfirmingCancel(false)}
              className="flex-1 rounded-xl bg-slate-100 py-2.5 text-sm font-medium text-slate-700"
            >
              Не отменять
            </button>
            <button
              onClick={() => cancelMutation.mutate()}
              disabled={cancelMutation.isPending}
              className="flex-1 rounded-xl bg-red-600 py-2.5 text-sm font-medium text-white disabled:opacity-50"
            >
              {cancelMutation.isPending ? 'Отменяем…' : 'Да, отменить'}
            </button>
          </div>
        </div>
      )}

      {canRate && (
        <button
          onClick={() => navigate(`/bookings/${booking.id}/rate`)}
          className="mt-6 w-full rounded-xl bg-slate-900 py-3 text-sm font-medium text-white"
        >
          Оценить маршала
        </button>
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
