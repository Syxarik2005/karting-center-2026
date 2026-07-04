/// Модель маршала (из вложенного объекта Slot.marshal).
class MarshalModel {
  final String id;
  final String name;
  final String avatarUrl;
  final double rating;

  const MarshalModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.rating,
  });

  factory MarshalModel.fromJson(Map<String, dynamic> json) {
    return MarshalModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

/// Модель слота заезда (из GET /slots, GET /slots/{id}).
/// Поля 1:1 с components.schemas.Slot в 01-analysis/api/openapi.yaml.
class SlotModel {
  final String id;
  final DateTime startTime;
  final String trackConfig; // "SHORT" | "LONG"
  final MarshalModel marshal;
  final int availableKarts;
  final int maxKarts;
  final String status; // "SCHEDULED" | "CANCELLED_BY_WEATHER" | "COMPLETED"
  final int rentalTariff;
  final String gatheringPlace;

  const SlotModel({
    required this.id,
    required this.startTime,
    required this.trackConfig,
    required this.marshal,
    required this.availableKarts,
    required this.maxKarts,
    required this.status,
    required this.rentalTariff,
    required this.gatheringPlace,
  });

  bool get isFull => availableKarts <= 0;
  bool get isBookable => status == 'SCHEDULED' && !isFull;

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String? ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      trackConfig: json['track_config'] as String? ?? 'SHORT',
      marshal: MarshalModel.fromJson(
        json['marshal'] as Map<String, dynamic>? ?? const {},
      ),
      availableKarts: json['available_karts'] as int? ?? 0,
      maxKarts: json['max_karts'] as int? ?? 0,
      status: json['status'] as String? ?? 'SCHEDULED',
      rentalTariff: json['rental_tariff'] as int? ?? 0,
      gatheringPlace: json['gathering_place'] as String? ?? '',
    );
  }
}
