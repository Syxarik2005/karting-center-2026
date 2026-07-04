import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/booking_model.dart';

/// Удалённый источник данных для бронирований.
class BookingsRemoteDatasource {
  final Dio _dio;

  BookingsRemoteDatasource(this._dio);

  /// POST /bookings — создать бронирование.
  Future<BookingModel> createBooking(CreateBookingRequest request) async {
    final response = await _dio.post(
      ApiConstants.bookings,
      data: request.toJson(),
    );
    return BookingModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /bookings — список бронирований текущего клиента.
  Future<List<BookingModel>> getBookings({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      ApiConstants.bookings,
      queryParameters: {'limit': limit, 'offset': offset},
    );

    final list = response.data as List<dynamic>;
    return list
        .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// POST /bookings/{id}/cancel — отмена бронирования.
  Future<BookingModel> cancelBooking(String bookingId) async {
    final response = await _dio.post(ApiConstants.cancelBooking(bookingId));
    return BookingModel.fromJson(response.data as Map<String, dynamic>);
  }
}
