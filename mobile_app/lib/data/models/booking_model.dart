/// Модель бронирования (из GET /bookings).
class BookingModel {
  final String id;
  final String clientId;
  final String slotId;
  final int seatsCount;
  final int rentalCount;
  final String priceTotal;
  final String status; // confirmed, cancelled
  final String? createdAt;

  const BookingModel({
    required this.id,
    required this.clientId,
    required this.slotId,
    required this.seatsCount,
    required this.rentalCount,
    required this.priceTotal,
    required this.status,
    this.createdAt,
  });

  bool get isCancelled => status == 'cancelled';

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      slotId: json['slot_id'] as String? ?? '',
      seatsCount: json['seats_count'] as int? ?? 0,
      rentalCount: json['rental_count'] as int? ?? 0,
      priceTotal: json['price_total'] as String? ?? '0',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Запрос на создание бронирования.
class CreateBookingRequest {
  final String slotId;
  final int seatsCount;
  final int rentalCount;

  const CreateBookingRequest({
    required this.slotId,
    required this.seatsCount,
    this.rentalCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'slot_id': slotId,
        'seats_count': seatsCount,
        'rental_count': rentalCount,
      };
}
