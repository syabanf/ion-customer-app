import 'auth_user.dart';

/// Driving port for the auth feature.
///
/// The BLoC depends on this interface, not on the HTTP implementation.
/// Tests substitute fakes; the real implementation lives in
/// features/auth/data/auth_repository_impl.dart.
abstract class AuthRepository {
  /// Exchanges credentials for a session. Persists tokens on success.
  Future<AuthSession> login({required String email, required String password});

  /// Returns the current session if a stored token is still valid, or
  /// null if not signed in / unable to refresh. Called on app start.
  Future<AuthSession?> restore();

  /// Revokes the refresh token server-side and clears local storage.
  /// Best-effort: completes even if the network call fails.
  Future<void> logout();

  /// Refreshes the access token using the stored refresh token.
  /// Returns the new access token, or null if refresh failed.
  /// Wired into the ApiClient's refresh hook at DI setup time.
  Future<String?> refreshAccessToken(String refreshToken);
}
