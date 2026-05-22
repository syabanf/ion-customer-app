import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../domain/auth_user.dart';

/// Thin wire-level binding to identity-svc endpoints.
/// Knows JSON shapes; knows no domain rules. Dio types are allowed here
/// because this is the data layer — the BLoC and domain don't see them.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  static final _post = Options(method: 'POST', contentType: 'application/json');

  Future<LoginRaw> login({required String email, required String password}) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/identity/auth/login',
      data: {'email': email, 'password': password},
      options: _post,
      skipAuth: true,
    );
    return LoginRaw.fromJson(res.data!);
  }

  Future<LoginRaw> refresh(String refreshToken) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/identity/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: _post,
      skipAuth: true,
    );
    return LoginRaw.fromJson(res.data!);
  }

  Future<void> logout(String refreshToken) async {
    await _client.request<dynamic>(
      '/api/identity/auth/logout',
      data: {'refresh_token': refreshToken},
      options: _post,
      skipAuth: true,
    );
  }

  Future<AuthSession> me() async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/identity/auth/me',
    );
    return _sessionFromJson(res.data!);
  }
}

/// Wire-level shape of a /login or /refresh response.
class LoginRaw {
  LoginRaw({
    required this.accessToken,
    required this.refreshToken,
    required this.session,
  });

  factory LoginRaw.fromJson(Map<String, dynamic> json) {
    return LoginRaw(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      session: _sessionFromJson(json),
    );
  }

  final String accessToken;
  final String refreshToken;
  final AuthSession session;
}

AuthSession _sessionFromJson(Map<String, dynamic> json) {
  final user = json['user'] as Map<String, dynamic>;
  return AuthSession(
    user: AuthUser(
      id: user['id'] as String,
      employeeId: (user['employee_id'] as String?) ?? '',
      fullName: user['full_name'] as String,
      email: user['email'] as String,
      phone: (user['phone'] as String?) ?? '',
      branchId: user['branch_id'] as String?,
      branchLevel: user['branch_level'] as String?,
      active: user['active'] as bool,
    ),
    roles: List<String>.from(json['roles'] as List<dynamic>? ?? <dynamic>[]),
    permissions:
        List<String>.from(json['permissions'] as List<dynamic>? ?? <dynamic>[]),
  );
}
