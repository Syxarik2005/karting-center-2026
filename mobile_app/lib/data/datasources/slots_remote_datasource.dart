import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/slot_model.dart';

/// Удалённый источник данных для слотов прогулок.
class SlotsRemoteDatasource {
  final Dio _dio;

  SlotsRemoteDatasource(this._dio);

  /// GET /slots — список слотов с фильтрацией.
  Future<List<SlotModel>> getSlots({
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;

    final response = await _dio.get(
      ApiConstants.slots,
      queryParameters: queryParams,
    );

    final list = response.data as List<dynamic>;
    return list
        .map((json) => SlotModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /slots/{id} — конкретный слот.
  Future<SlotModel> getSlotById(String id) async {
    final response = await _dio.get(ApiConstants.slotById(id));
    return SlotModel.fromJson(response.data as Map<String, dynamic>);
  }
}
