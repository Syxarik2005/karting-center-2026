import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { getBooking, rateMarshal } from '../api/mockApi';
import { StarRating } from '../components/StarRating';
import { Skeleton } from '../components/States';

export function RateMarshalPage() {
  const { bookingId } = useParams<{ bookingId: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState('');

  const { data: booking, isLoading } = useQuery({
    queryKey: ['booking', bookingId],
    queryFn: () => getBooking(bookingId!),
    enabled: !!bookingId,
  });

  const mutation = useMutation({
    mutationFn: () => rateMarshal(bookingId!, rating, comment || undefined),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['booking', bookingId] });
      navigate(`/bookings/${bookingId}`);
    },
  });

  if (isLoading || !booking) {
    return (
      <div className="px-4 pt-6">
        <Skeleton rows={1} />
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh flex-col justify-end bg-black/40">
      <div className="rounded-t-3xl bg-white p-6 pb-10">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-slate-200" />
        <div className="text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-slate-100 text-2xl">
            🏁
          </div>
          <h2 className="mt-3 text-lg font-bold text-slate-900">{booking.slot.marshal.name}</h2>
          <p className="text-sm text-slate-500">Как прошёл заезд?</p>
        </div>

        <div className="mt-6">
          <StarRating value={rating} onChange={setRating} />
        </div>

        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder="Комментарий (необязательно)"
          rows={3}
          className="mt-4 w-full rounded-xl border border-slate-200 p-3 text-sm outline-none focus:border-slate-400"
        />

        <button
          onClick={() => mutation.mutate()}
          disabled={rating === 0 || mutation.isPending}
          className="mt-4 w-full rounded-xl bg-slate-900 py-3 font-medium text-white disabled:opacity-40"
        >
          {mutation.isPending ? 'Отправляем…' : 'Отправить'}
        </button>
        <button
          onClick={() => navigate(-1)}
          className="mt-2 w-full py-2 text-sm font-medium text-slate-500"
        >
          Позже
        </button>
      </div>
    </div>
  );
}
