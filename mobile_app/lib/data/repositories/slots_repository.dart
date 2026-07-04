import 'package:dio/dio.dart';

import '../datasources/slots_remote_datasource.dart';
import '../models/slot_model.dart';

/// Репозиторий слотов — обработка ошибок поверх datasource.
class SlotsRepository {
  final SlotsRemoteDatasource _datasource;

  SlotsRepository(this._datasource);

  /// Получить список доступных слотов.
  Future<List<SlotModel>> getSlots({
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _datasource.getSlots(
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
        offset: offset,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Получить конкретный слот по ID.
  Future<SlotModel> getSlotById(String id) async {
    try {
      return await _datasource.getSlotById(id);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Exception _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Нет соединения. Проверьте интернет.');
    }
    if (e.response?.statusCode == 404) {
      return Exception('Заезд не найден');
    }
    return Exception('Не удалось загрузить расписание заездов');
  }
}
