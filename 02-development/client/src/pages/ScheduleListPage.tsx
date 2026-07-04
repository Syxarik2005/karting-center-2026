import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { getSlots } from '../api/mockApi';
import { SlotCard } from '../components/SlotCard';
import { Skeleton, EmptyState, ErrorState } from '../components/States';
import type { TrackConfig } from '../api/types';

const HORIZON_OPTIONS = [
  { label: '7 дней', days: 7 },
  { label: '14 дней', days: 14 },
  { label: '30 дней', days: 30 },
];

export function ScheduleListPage() {
  const navigate = useNavigate();
  const [horizonDays, setHorizonDays] = useState(7);
  const [track, setTrack] = useState<TrackConfig | 'ALL'>('ALL');

  const dateTo = useMemo(() => {
    const d = new Date();
    d.setDate(d.getDate() + horizonDays);
    return d.toISOString();
  }, [horizonDays]);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ['slots', horizonDays, track],
    queryFn: () =>
      getSlots({
        dateTo,
        trackConfig: track === 'ALL' ? undefined : track,
      }),
  });

  return (
    <div className="px-4 pb-24 pt-6">
      <h1 className="text-xl font-bold text-slate-900">Расписание заездов</h1>
      <p className="mt-1 text-sm text-slate-500">
        Картинг-центр «Апекс» · выберите заезд и запишитесь
      </p>

      <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
        {HORIZON_OPTIONS.map((opt) => (
          <button
            key={opt.days}
            onClick={() => setHorizonDays(opt.days)}
            className={`shrink-0 rounded-full px-3.5 py-1.5 text-sm font-medium ${
              horizonDays === opt.days
                ? 'bg-slate-900 text-white'
                : 'bg-slate-100 text-slate-600'
            }`}
          >
            {opt.label}
          </button>
        ))}
        <span className="mx-1 my-auto h-4 w-px bg-slate-200" />
        {(['ALL', 'SHORT', 'LONG'] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTrack(t)}
            className={`shrink-0 rounded-full px-3.5 py-1.5 text-sm font-medium ${
              track === t ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600'
            }`}
          >
            {t === 'ALL' ? 'Все трассы' : t === 'SHORT' ? 'Короткая' : 'Длинная'}
          </button>
        ))}
      </div>

      <div className="mt-4">
        {isLoading && <Skeleton />}
        {isError && (
          <ErrorState message="Не удалось загрузить расписание" onRetry={() => refetch()} />
        )}
        {data && data.length === 0 && (
          <EmptyState
            title="Пока нет доступных заездов"
            subtitle="Попробуйте увеличить период или сменить трассу"
          />
        )}
        {data && data.length > 0 && (
          <div className="space-y-3">
            {data.map((slot) => (
              <SlotCard key={slot.id} slot={slot} onClick={() => navigate(`/slots/${slot.id}`)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
