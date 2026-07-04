import { useQuery } from '@tanstack/react-query';
import { getProfile } from '../api/mockApi';
import { Skeleton, ErrorState } from '../components/States';

export function ProfilePage() {
  const { data: profile, isLoading, isError } = useQuery({
    queryKey: ['profile'],
    queryFn: getProfile,
  });

  if (isLoading) {
    return (
      <div className="px-4 pt-6">
        <Skeleton rows={1} />
      </div>
    );
  }
  if (isError || !profile) {
    return (
      <div className="px-4 pt-6">
        <ErrorState message="Не удалось загрузить профиль" />
      </div>
    );
  }

  return (
    <div className="px-4 pb-24 pt-6">
      <h1 className="text-xl font-bold text-slate-900">Профиль</h1>

      <div className="mt-4 flex items-center gap-3">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-slate-100 text-2xl">
          🙂
        </div>
        <div>
          <p className="text-lg font-semibold text-slate-900">{profile.name}</p>
          <p className="text-sm text-slate-500">{profile.phone}</p>
        </div>
      </div>

      {profile.is_regular && (
        <div className="mt-4 flex items-center gap-2 rounded-2xl bg-amber-50 p-3 text-sm text-amber-800">
          <span>⭐</span>
          <span>Постоянный клиент «Апекс»</span>
        </div>
      )}

      <div className="mt-6 space-y-2">
        <MenuRow label="Редактировать профиль" />
        <MenuRow label="Уведомления" />
        <MenuRow label="Выйти из аккаунта" danger />
      </div>
    </div>
  );
}

function MenuRow({ label, danger }: { label: string; danger?: boolean }) {
  return (
    <button
      className={`w-full rounded-xl border border-slate-200 bg-white p-3.5 text-left text-sm font-medium ${
        danger ? 'text-red-600' : 'text-slate-700'
      }`}
    >
      {label}
    </button>
  );
}
