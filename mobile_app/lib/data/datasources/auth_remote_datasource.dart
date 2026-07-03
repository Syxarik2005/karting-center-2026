import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/auth_models.dart';

/// Удалённый источник данных для авторизации.
class AuthRemoteDatasource {
  final Dio _dio;

  AuthRemoteDatasource(this._dio);

  /// POST /auth/send-code — отправка SMS-кода.
  Future<SendCodeResponse> sendCode(SendCodeRequest request) async {
    final response = await _dio.post(
      ApiConstants.sendCode,
      data: request.toJson(),
    );
    return SendCodeResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /auth/login — вход по телефону + OTP-коду.
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: request.toJson(),
    );
    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
