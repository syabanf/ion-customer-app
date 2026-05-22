import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the access + refresh tokens in the OS keystore.
///
/// Why secure_storage:
///   - Android: EncryptedSharedPreferences backed by Keystore.
///   - iOS:    Keychain with first-unlock policy.
///   - Plain SharedPreferences / NSUserDefaults would be readable by
///     anyone with filesystem access on a jailbroken device.
class TokenStorage {
  TokenStorage(this._storage);

  static const _kAccess = 'ion.access_token';
  static const _kRefresh = 'ion.refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  Future<void> write({String? access, String? refresh}) async {
    if (access == null) {
      await _storage.delete(key: _kAccess);
    } else {
      await _storage.write(key: _kAccess, value: access);
    }
    if (refresh == null) {
      await _storage.delete(key: _kRefresh);
    } else {
      await _storage.write(key: _kRefresh, value: refresh);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
