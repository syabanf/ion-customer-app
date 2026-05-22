// Push-notification bootstrap. Kill-switched by ION_PUSH_ENABLED so we
// can ship the dependency + wire the call sites in advance, then flip
// the env at build time once the Firebase service-account JSON +
// google-services.json land.
//
// Until enabled, every public method is a no-op. The backend
// /platform/device-token endpoint exists already (migration 0040,
// permission platform.device_token.register) so the day-1 flip is
// just env + plist/json drop-in.
//
// Why we don't initialise Firebase until enabled: firebase_core's
// Firebase.initializeApp throws if no platform config is present.
// Apps that boot before the config is provisioned would crash on
// startup. The flag-guard lets us merge the call sites today without
// breaking dev builds.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';

/// Public surface for the rest of the app. Apps call
/// `PushNotifier.bootOnce(api)` after auth completes — typically
/// inside the AuthBloc's authenticated state listener.
class PushNotifier {
  PushNotifier._();

  /// Set at compile-time via:
  ///   --dart-define=ION_PUSH_ENABLED=true
  /// We default to false so dev builds + CI Flutter analyze don't
  /// try to call into Firebase without a platform config.
  static const bool _enabled = bool.fromEnvironment(
    'ION_PUSH_ENABLED',
    defaultValue: false,
  );

  static bool _booted = false;
  static String? _lastToken;

  /// One-shot bootstrap. Safe to call repeatedly — extra calls are
  /// debounced. When [_enabled] is false this returns immediately.
  ///
  /// Registers the FCM token with the backend's
  /// `/platform/device-token` endpoint so the dispatcher in
  /// `pkg/notifyx` can address this device.
  static Future<void> bootOnce(ApiClient api) async {
    if (!_enabled) {
      if (kDebugMode) {
        debugPrint('PushNotifier: ION_PUSH_ENABLED=false; skipping FCM init.');
      }
      return;
    }
    if (_booted) return;
    _booted = true;

    try {
      // Firebase.initializeApp picks up the platform config that the
      // FlutterFire CLI generates. We don't pass options here so the
      // file drop-in (google-services.json / GoogleService-Info.plist)
      // is the single source of truth.
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      // iOS / web require explicit permission. Android grants by default.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          debugPrint('PushNotifier: permission denied — registration skipped.');
        }
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('PushNotifier: getToken returned null — skipping.');
        }
        return;
      }
      await _registerToken(api, token);
      _lastToken = token;

      // FCM rotates tokens periodically (re-install, app data clear,
      // device reset). Re-register on rotation so the dispatcher
      // doesn't sit on a stale id.
      messaging.onTokenRefresh.listen((newToken) async {
        if (newToken == _lastToken) return;
        _lastToken = newToken;
        await _registerToken(api, newToken);
      });
    } catch (e, st) {
      // Non-fatal: a missing platform config or rate-limit just means
      // no push. Keep the app booting.
      if (kDebugMode) {
        debugPrint('PushNotifier: boot failed — $e\n$st');
      }
    }
  }

  static Future<void> _registerToken(ApiClient api, String token) async {
    try {
      await api.dio.post(
        '/api/platform/device-tokens',
        data: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotifier: device-token register failed — $e');
      }
    }
  }
}
