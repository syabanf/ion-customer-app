import '../../core/errors/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_api.dart';

/// HTTP-backed implementation of [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.api, required this.tokens});

  final AuthApi api;
  final TokenStorage tokens;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final raw = await api.login(email: email, password: password);
    await tokens.write(access: raw.accessToken, refresh: raw.refreshToken);
    return raw.session;
  }

  /// On app start. If a valid access token exists, hydrate via /me.
  /// If /me returns 401, the ApiClient's auto-refresh interceptor will
  /// have already attempted refresh — if THAT also fails, /me throws and
  /// we return null (user must sign in again).
  @override
  Future<AuthSession?> restore() async {
    final access = await tokens.readAccess();
    if (access == null) return null;
    try {
      return await api.me();
    } on ApiException catch (e) {
      if (e.isAuth) {
        await tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final rt = await tokens.readRefresh();
    if (rt != null) {
      try {
        await api.logout(rt);
      } catch (_) {
        // best-effort: server-side revoke can fail; we still clear locally
      }
    }
    await tokens.clear();
  }

  /// Wired into ApiClient.refreshHandler at startup so the interceptor
  /// can call us back without depending on this package.
  @override
  Future<String?> refreshAccessToken(String refreshToken) async {
    try {
      final raw = await api.refresh(refreshToken);
      await tokens.write(access: raw.accessToken, refresh: raw.refreshToken);
      return raw.accessToken;
    } on ApiException {
      await tokens.clear();
      return null;
    }
  }
}
