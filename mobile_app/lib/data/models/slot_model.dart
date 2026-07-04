/// Модель слота прогулки (из GET /slots, GET /slots/{id}).
class SlotModel {
  final String id;
  final String routeName;
  final String? routeDescription;
  final DateTime startAt;
  final int durationMinutes;
  final int maxSeats;
  final int bookedSeats;
  final String pricePerSeat;
  final String? priceRental;

  const SlotModel({
    required this.id,
    required this.routeName,
    this.routeDescription,
    required this.startAt,
    required this.durationMinutes,
    required this.maxSeats,
    required this.bookedSeats,
    required this.pricePerSeat,
    this.priceRental,
  });

  int get availableSeats => maxSeats - bookedSeats;
  bool get isFull => availableSeats <= 0;

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      routeDescription: json['route_description'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      maxSeats: json['max_seats'] as int? ?? 0,
      bookedSeats: json['booked_seats'] as int? ?? 0,
      pricePerSeat: json['price_per_seat'] as String? ?? '0',
      priceRental: json['price_rental'] as String?,
    );
  }
}
