import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SlotDetailsPage } from './SlotDetailsPage';
import { createBooking, resetMockDb } from '../api/mockApi';

function renderSlotPage(slotId: string) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[`/slots/${slotId}`]}>
        <Routes>
          <Route path="/slots/:slotId" element={<SlotDetailsPage />} />
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

describe('SlotDetailsPage', () => {
  it('disables booking and shows "Мест нет" for an already-full slot', async () => {
    renderSlotPage('slot-3'); // seeded with available_karts: 0

    const button = await screen.findByRole('button', { name: /мест нет/i });
    expect(button).toBeDisabled();
  });

  it('shows a conflict message instead of crashing when the last kart is taken between page-load and submit', async () => {
    const user = userEvent.setup();
    renderSlotPage('slot-2'); // seeded with available_karts: 1

    // The page has already fetched slot-2 with 1 kart available and shows an
    // enabled "Записаться" button — then someone else takes the last kart
    // before this user submits, exactly like BR-01 describes.
    const bookButton = await screen.findByRole('button', { name: /записаться/i });
    await createBooking({ slotId: 'slot-2', gearType: 'OWN' });

    await user.click(bookButton);

    expect(
      await screen.findByText(/места на этот заезд закончились/i),
    ).toBeInTheDocument();
  });
});
