import 'slot_model.dart';

/// Модель бронирования (из GET /client/bookings).
/// Поля 1:1 с components.schemas.Booking в 01-analysis/api/openapi.yaml.
class BookingModel {
  final String id;
  final SlotModel slot;
  final String status; // ACTIVE | CANCELLED_BY_CLIENT | CANCELLED_BY_CENTER | COMPLETED
  final String gearType; // OWN | RENTAL
  final String? cancellationReason; // present only if status == CANCELLED_BY_CENTER

  const BookingModel({
    required this.id,
    required this.slot,
    required this.status,
    required this.gearType,
    this.cancellationReason,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isCancelledByCenter => status == 'CANCELLED_BY_CENTER';

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String? ?? '',
      slot: SlotModel.fromJson(json['slot'] as Map<String, dynamic>? ?? const {}),
      status: json['status'] as String? ?? 'ACTIVE',
      gearType: json['gear_type'] as String? ?? 'OWN',
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }
}

/// Запрос на создание бронирования — POST /client/bookings.
class CreateBookingRequest {
  final String slotId;
  final String gearType; // OWN | RENTAL

  const CreateBookingRequest({
    required this.slotId,
    required this.gearType,
  });

  Map<String, dynamic> toJson() => {
        'slot_id': slotId,
        'gear_type': gearType,
      };
}
