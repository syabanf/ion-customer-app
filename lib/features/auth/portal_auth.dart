// Customer-portal auth client + token store. The customer flow is OTP
// based, distinct from the staff-app email/password login that lives
// in ion_core_shared. We keep the two completely separate so a
// customer device can't accidentally consume staff JWTs.
//
// Tokens live in flutter_secure_storage (Keystore / Keychain). The
// refresh token is opaque "<session-uuid>.<secret>"; the access
// token is a regular ION JWT with role='customer'.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PortalAuthApi — thin wrapper over /portal/auth/* and the data
/// reads. All calls go through the same Dio instance; the
/// interceptor attaches the customer access-token automatically.
class PortalAuthApi {
  PortalAuthApi({Dio? dio, FlutterSecureStorage? store, String? baseUrl})
      : _dio = dio ?? _defaultDio(baseUrl),
        _store = store ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _store;

  static const _kAccess = 'portal.access';
  static const _kRefresh = 'portal.refresh';

  static Dio _defaultDio(String? baseUrl) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ??
          const String.fromEnvironment('API_URL',
              defaultValue: 'http://localhost:8080'),
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    ));
    return dio;
  }

  Dio get dio => _dio;

  /// Attach a per-request Authorization header. Called by the wiring
  /// in main.dart so the rest of the app can use the raw Dio.
  void installAuthHeader(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthHeader() {
    _dio.options.headers.remove('Authorization');
  }

  // --------------- token storage ---------------

  Future<String?> readAccess() => _store.read(key: _kAccess);
  Future<String?> readRefresh() => _store.read(key: _kRefresh);
  Future<void> writeTokens({required String access, required String refresh}) async {
    await _store.write(key: _kAccess, value: access);
    await _store.write(key: _kRefresh, value: refresh);
    installAuthHeader(access);
  }

  Future<void> clearTokens() async {
    await _store.delete(key: _kAccess);
    await _store.delete(key: _kRefresh);
    clearAuthHeader();
  }

  // --------------- OTP flow ---------------

  Future<OtpRequestResult> requestOtp({
    required String customerNumber,
    String? phoneLast4,
    String? email,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/portal/auth/otp-request',
        data: {
          'customer_number': customerNumber,
          if (phoneLast4 != null && phoneLast4.isNotEmpty) 'phone_last4': phoneLast4,
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );
      return OtpRequestResult(
        sent: (res.data?['sent'] as bool?) ?? true,
        debugOtp: res.data?['debug_otp'] as String?,
      );
    } on DioException catch (e) {
      throw PortalException(_message(e));
    }
  }

  Future<void> verifyOtp({
    required String customerNumber,
    required String otp,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/portal/auth/otp-verify',
        data: {'customer_number': customerNumber, 'otp': otp},
      );
      final m = res.data ?? const <String, dynamic>{};
      final access = m['access_token'] as String?;
      final refresh = m['refresh_token'] as String?;
      if (access == null || refresh == null) {
        throw PortalException('Invalid server response — missing tokens.');
      }
      await writeTokens(access: access, refresh: refresh);
    } on DioException catch (e) {
      throw PortalException(_message(e));
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/portal/logout');
    } catch (_) {
      // network error during logout is non-fatal — we still wipe local tokens.
    }
    await clearTokens();
  }

  // --------------- bootstrap (auto-login on app open) ---------------

  /// Returns true if the persisted tokens still work. If the access
  /// token is expired we try a refresh; on failure we wipe + return false.
  Future<bool> bootstrap() async {
    final access = await readAccess();
    final refresh = await readRefresh();
    if (access == null || refresh == null) return false;
    installAuthHeader(access);
    try {
      await _dio.get('/portal/me');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        return false;
      }
    }
    // Access token rejected → try refresh.
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/portal/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final newAccess = r.data?['access_token'] as String?;
      if (newAccess == null) return false;
      await _store.write(key: _kAccess, value: newAccess);
      installAuthHeader(newAccess);
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  String _message(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      return (body['error']['message'] as String?) ?? e.message ?? 'Unknown error';
    }
    return e.message ?? 'Network error';
  }
}

class OtpRequestResult {
  const OtpRequestResult({required this.sent, this.debugOtp});
  final bool sent;

  /// Set in demo mode (CRM_PORTAL_OTP_DEMO=true on the server) so a
  /// demoer can sign in without SMS/WhatsApp wired.
  final String? debugOtp;
}

class PortalException implements Exception {
  PortalException(this.message);
  final String message;
  @override
  String toString() => message;
}

// Convenience flag for "is the app currently authenticated?" — used
// by the router redirect.
class PortalAuthState extends ChangeNotifier {
  bool _authed = false;
  bool get isAuthed => _authed;
  set isAuthed(bool v) {
    if (v == _authed) return;
    _authed = v;
    notifyListeners();
  }
}
