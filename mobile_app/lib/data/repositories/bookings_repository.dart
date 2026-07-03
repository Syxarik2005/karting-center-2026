import 'package:dio/dio.dart';

import '../datasources/bookings_remote_datasource.dart';
import '../models/booking_model.dart';

/// Репозиторий бронирований — обработка ошибок поверх datasource.
class BookingsRepository {
  final BookingsRemoteDatasource _datasource;

  BookingsRepository(this._datasource);

  /// Создать бронирование.
  Future<BookingModel> createBooking({
    required String slotId,
    required int seatsCount,
    int rentalCount = 0,
  }) async {
    try {
      return await _datasource.createBooking(
        CreateBookingRequest(
          slotId: slotId,
          seatsCount: seatsCount,
          rentalCount: rentalCount,
        ),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Получить список бронирований.
  Future<List<BookingModel>> getBookings({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _datasource.getBookings(limit: limit, offset: offset);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Отменить бронирование.
  Future<BookingModel> cancelBooking(String bookingId) async {
    try {
      return await _datasource.cancelBooking(bookingId);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Exception _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Нет соединения. Проверьте интернет.');
    }
    final statusCode = e.response?.statusCode;
    switch (statusCode) {
      case 401:
        return Exception('Необходимо войти заново');
      case 409:
        return Exception('Конфликт: ${e.response?.data}');
      default:
        return Exception('Не удалось выполнить операцию');
    }
  }
}
