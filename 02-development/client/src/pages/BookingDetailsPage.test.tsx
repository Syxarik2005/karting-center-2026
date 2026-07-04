import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BookingDetailsPage } from './BookingDetailsPage';
import { createBooking, resetMockDb } from '../api/mockApi';
import type { Booking } from '../api/types';

function renderBookingPage(bookingId: string) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[`/bookings/${bookingId}`]}>
        <Routes>
          <Route path="/bookings/:bookingId" element={<BookingDetailsPage />} />
        </Routes>
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

describe('BookingDetailsPage — cancellation', () => {
  it('cancels an active booking well outside the cutoff', async () => {
    const user = userEvent.setup();
    const booking: Booking = await createBooking({ slotId: 'slot-1', gearType: 'OWN' });
    renderBookingPage(booking.id);

    const cancelButton = await screen.findByRole('button', { name: /отменить запись/i });
    await user.click(cancelButton);

    const confirmButton = await screen.findByRole('button', { name: /да, отменить/i });
    await user.click(confirmButton);

    expect(await screen.findByText(/отменена вами/i)).toBeInTheDocument();
  });

  it('shows a clear error instead of cancelling when inside the cutoff window', async () => {
    const user = userEvent.setup();
    const booking: Booking = await createBooking({
      slotId: 'slot-9-near-term',
      gearType: 'OWN',
    });
    renderBookingPage(booking.id);

    const cancelButton = await screen.findByRole('button', { name: /отменить запись/i });
    await user.click(cancelButton);
    const confirmButton = await screen.findByRole('button', { name: /да, отменить/i });
    await user.click(confirmButton);

    expect(
      await screen.findByText(/отмена невозможна менее чем за 60 минут/i),
    ).toBeInTheDocument();
    // Status must still read "Активна" — the UI shouldn't have flipped state
    // locally before the server (mock) actually confirmed the cancellation.
    expect(screen.getByText(/активна/i)).toBeInTheDocument();
  });
});
