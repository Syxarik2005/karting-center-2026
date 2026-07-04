export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString('ru-RU', {
    weekday: 'short',
    day: 'numeric',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
}

export function trackLabel(track: 'SHORT' | 'LONG'): string {
  return track === 'SHORT' ? 'Короткая · для новичков' : 'Длинная · для опытных';
}

export function bookingStatusLabel(status: string): { label: string; tone: string } {
  switch (status) {
    case 'ACTIVE':
      return { label: 'Активна', tone: 'bg-emerald-100 text-emerald-700' };
    case 'CANCELLED_BY_CLIENT':
      return { label: 'Отменена вами', tone: 'bg-slate-200 text-slate-600' };
    case 'CANCELLED_BY_CENTER':
      return { label: 'Отменена центром', tone: 'bg-amber-100 text-amber-800' };
    case 'COMPLETED':
      return { label: 'Завершена', tone: 'bg-sky-100 text-sky-700' };
    default:
      return { label: status, tone: 'bg-slate-100 text-slate-600' };
  }
}
