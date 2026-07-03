import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../datasources/auth_remote_datasource.dart';
import '../models/auth_models.dart';

/// Репозиторий авторизации — управляет токенами и обработкой ошибок.
class AuthRepository {
  final AuthRemoteDatasource _datasource;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'access_token';

  AuthRepository(this._datasource, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Отправить SMS-код на номер.
  Future<SendCodeResponse> sendCode(String phone) async {
    try {
      return await _datasource.sendCode(SendCodeRequest(phone: phone));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Войти по коду. Сохраняет токен при успехе.
  Future<LoginResponse> login({
    required String phone,
    required String code,
    String? name,
  }) async {
    try {
      final response = await _datasource.login(
        LoginRequest(phone: phone, code: code, name: name),
      );
      await _storage.write(key: _tokenKey, value: response.token);
      return response;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Проверить, есть ли сохранённый токен.
  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Выйти — стереть токен.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Маппинг Dio-ошибок в понятные исключения.
  Exception _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Нет соединения. Проверьте интернет.');
    }
    final statusCode = e.response?.statusCode;
    switch (statusCode) {
      case 400:
        return Exception('Неверный формат данных');
      case 401:
        return Exception('Неверный код');
      case 429:
        return Exception('Слишком много попыток. Подождите.');
      default:
        return Exception('Произошла ошибка. Попробуйте позже.');
    }
  }
}
