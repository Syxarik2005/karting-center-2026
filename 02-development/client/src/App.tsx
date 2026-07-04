import { Route, Routes, useLocation } from 'react-router-dom';
import { BottomNav } from './components/BottomNav';
import { ScheduleListPage } from './pages/ScheduleListPage';
import { SlotDetailsPage } from './pages/SlotDetailsPage';
import { MyBookingsPage } from './pages/MyBookingsPage';
import { BookingDetailsPage } from './pages/BookingDetailsPage';
import { RateMarshalPage } from './pages/RateMarshalPage';
import { ProfilePage } from './pages/ProfilePage';

function App() {
  const location = useLocation();
  const isRateSheet = location.pathname.endsWith('/rate');

  return (
    <div className="mx-auto min-h-dvh max-w-md bg-slate-50">
      <Routes>
        <Route path="/" element={<ScheduleListPage />} />
        <Route path="/slots/:slotId" element={<SlotDetailsPage />} />
        <Route path="/bookings" element={<MyBookingsPage />} />
        <Route path="/bookings/:bookingId" element={<BookingDetailsPage />} />
        <Route path="/bookings/:bookingId/rate" element={<RateMarshalPage />} />
        <Route path="/profile" element={<ProfilePage />} />
      </Routes>
      {!isRateSheet && <BottomNav />}
    </div>
  );
}

export default App;
