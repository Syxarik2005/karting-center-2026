/// API endpoint constants for the Apex backend.
class ApiConstants {
  ApiConstants._();

  /// Base URL — подставь IP своего бэкенда для Android-эмулятора (10.0.2.2)
  /// или localhost для iOS-симулятора / веба.
  static const String baseUrl = 'http://10.0.2.2:8080';

  // ── Auth ──
  static const String sendCode = '/auth/send-code';
  static const String login = '/auth/login';

  // ── Slots ──
  static const String slots = '/slots';
  static String slotById(String id) => '/slots/$id';

  // ── Bookings (client-scoped, matches 01-analysis/api/openapi.yaml) ──
  static const String bookings = '/client/bookings';
  static String cancelBooking(String id) => '/client/bookings/$id/cancel';
  static String rateBooking(String id) => '/client/bookings/$id/rate';
  static const String profile = '/client/profile';

  // ── Health ──
  static const String health = '/health';
}
