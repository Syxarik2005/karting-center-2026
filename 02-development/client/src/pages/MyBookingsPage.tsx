import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { getMyBookings } from '../api/mockApi';
import { BookingCard } from '../components/BookingCard';
import { Skeleton, EmptyState, ErrorState } from '../components/States';

export function MyBookingsPage() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<'upcoming' | 'past'>('upcoming');

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ['bookings'],
    queryFn: getMyBookings,
  });

  const filtered = useMemo(() => {
    if (!data) return [];
    return data.filter((b) => {
      const isUpcoming = b.status === 'ACTIVE';
      return tab === 'upcoming' ? isUpcoming : !isUpcoming;
    });
  }, [data, tab]);

  return (
    <div className="px-4 pb-24 pt-6">
      <h1 className="text-xl font-bold text-slate-900">Мои заезды</h1>

      <div className="mt-4 flex gap-2">
        <TabButton active={tab === 'upcoming'} onClick={() => setTab('upcoming')}>
          Предстоящие
        </TabButton>
        <TabButton active={tab === 'past'} onClick={() => setTab('past')}>
          Прошедшие/Отменённые
        </TabButton>
      </div>

      <div className="mt-4">
        {isLoading && <Skeleton />}
        {isError && (
          <ErrorState message="Не удалось загрузить брони" onRetry={() => refetch()} />
        )}
        {data && filtered.length === 0 && (
          <EmptyState
            title={tab === 'upcoming' ? 'Нет предстоящих записей' : 'Пока нет истории'}
            subtitle={tab === 'upcoming' ? 'Запишитесь на заезд из расписания' : undefined}
          />
        )}
        {filtered.length > 0 && (
          <div className="space-y-3">
            {filtered.map((b) => (
              <BookingCard key={b.id} booking={b} onClick={() => navigate(`/bookings/${b.id}`)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function TabButton({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex-1 rounded-full py-2 text-sm font-medium ${
        active ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600'
      }`}
    >
      {children}
    </button>
  );
}
