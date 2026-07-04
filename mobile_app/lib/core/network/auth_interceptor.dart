import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Перехватчик, который подставляет Bearer-токен из secure storage
/// и обрабатывает 401.
class AuthInterceptor extends Interceptor {
  static const _tokenKey = 'access_token';
  final FlutterSecureStorage _storage;

  AuthInterceptor({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // TODO: попытка refresh, если не удалась — стереть токен и на логин
      _storage.delete(key: _tokenKey);
    }
    handler.next(err);
  }
}
