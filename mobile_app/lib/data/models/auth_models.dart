/// Запрос на отправку SMS-кода.
class SendCodeRequest {
  final String phone;

  const SendCodeRequest({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

/// Ответ на отправку SMS-кода.
class SendCodeResponse {
  final String message;
  final int ttlSeconds;
  final int resendAfterSeconds;

  const SendCodeResponse({
    required this.message,
    required this.ttlSeconds,
    required this.resendAfterSeconds,
  });

  factory SendCodeResponse.fromJson(Map<String, dynamic> json) {
    return SendCodeResponse(
      message: json['message'] as String? ?? '',
      ttlSeconds: json['ttl_seconds'] as int? ?? 300,
      resendAfterSeconds: json['resend_after_seconds'] as int? ?? 60,
    );
  }
}

/// Запрос на логин (проверка OTP-кода).
class LoginRequest {
  final String phone;
  final String code;
  final String? name;

  const LoginRequest({
    required this.phone,
    required this.code,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'code': code,
        if (name != null) 'name': name,
      };
}

/// Ответ на логин.
class LoginResponse {
  final String token;
  final bool isNew;
  final ClientInfo client;

  const LoginResponse({
    required this.token,
    required this.isNew,
    required this.client,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      isNew: json['is_new'] as bool? ?? false,
      client: ClientInfo.fromJson(json['client'] as Map<String, dynamic>),
    );
  }
}

/// Информация о клиенте из ответа API.
class ClientInfo {
  final String id;
  final String name;
  final String phone;
  final String? createdAt;

  const ClientInfo({
    required this.id,
    required this.name,
    required this.phone,
    this.createdAt,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }
}
