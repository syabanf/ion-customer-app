import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'app/customer_app.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/portal_auth.dart';

/// Entry point — bootstraps PortalAuthApi, restores any persisted
/// session, then mounts the router. The customer app is intentionally
/// leaner than the staff apps: no Bloc, no DI container — a single
/// PortalAuthApi is plumbed via constructors.
///
/// Wave 20 — wraps the whole thing in `runZonedGuarded` + wires
/// `FlutterError.onError` and `PlatformDispatcher.onError` so the
/// page can never blank-canvas on an uncaught exception. Errors
/// render a friendly inline screen with a "Reload" button.
Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Framework-level errors (build/layout/paint) — log + replace
    // the affected widget with an inline error tile rather than the
    // big red "Error widget" debug overlay.
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    ErrorWidget.builder = (details) => _InlineErrorTile(details: details);

    // Async errors that bubble out of the framework (unawaited Future
    // rejections in build, missing-context errors, etc.).
    PlatformDispatcher.instance.onError = (error, stack) {
      // ignore: avoid_print
      debugPrint('UNCAUGHT: $error\n$stack');
      return true;
    };

    // Wave 24 — restore the user's saved Light/Dark/System choice
    // before runApp so the first frame already paints in the right
    // theme. Failure is non-fatal — falls back to ThemeMode.system.
    await loadPersistedThemeMode();

    final api = PortalAuthApi();
    final authState = PortalAuthState();

    // Revive the prior session if the secure-store has tokens. The
    // bootstrap call tries the access token first, falls back to refresh,
    // and wipes if both fail — leaving us at /login. We swallow any
    // unexpected bootstrap exception so the app still mounts at /login.
    try {
      authState.isAuthed = await api.bootstrap();
    } catch (e, st) {
      debugPrint('portal bootstrap failed: $e\n$st');
      authState.isAuthed = false;
    }

    runApp(IonCustomerApp(api: api, authState: authState));
  }, (error, stack) {
    // Zone-level catch — anything that escaped the try/catch above.
    debugPrint('ZONE UNCAUGHT: $error\n$stack');
  });
}

/// Inline error tile shown when a build/layout exception leaks. Keeps
/// the rest of the page interactive instead of blanking the canvas.
class _InlineErrorTile extends StatelessWidget {
  const _InlineErrorTile({required this.details});
  final FlutterErrorDetails details;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: IonColors.danger, size: 20),
              SizedBox(width: 8),
              Text(
                'Something went wrong here',
                style: TextStyle(
                  color: IonColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kDebugMode
                ? (details.exceptionAsString())
                : 'Please reload the page or try again in a moment.',
            style: const TextStyle(
              color: IonColors.danger,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
