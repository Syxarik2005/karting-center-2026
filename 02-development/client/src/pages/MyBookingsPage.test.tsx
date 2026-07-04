import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MyBookingsPage } from './MyBookingsPage';
import { createBooking, resetMockDb } from '../api/mockApi';

function renderPage() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/bookings']}>
        <MyBookingsPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  resetMockDb();
});

afterEach(() => {
  document.body.innerHTML = '';
});

describe('MyBookingsPage', () => {
  it('shows a freshly created active booking under "Предстоящие", not under past/cancelled', async () => {
    await createBooking({ slotId: 'slot-1', gearType: 'OWN' });
    renderPage();

    // Default tab is "Предстоящие" — the new active booking must appear here.
    expect(await screen.findByText(/активна/i)).toBeInTheDocument();

    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: /прошедшие/i }));

    // Switching tabs should hide the active booking (it belongs to the other tab).
    expect(screen.queryByText(/активна/i)).not.toBeInTheDocument();
    // The seeded COMPLETED booking should be visible instead.
    expect(await screen.findByText(/завершена/i)).toBeInTheDocument();
  });
});
