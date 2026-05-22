// In-app barrel for the formerly-shared core modules (auth, theme,
// HTTP client, DI, GPS, push, widgets). Wave 16 inlined the
// `ion_core_shared` package into each mobile app so the three
// binaries are now fully independent — each can pick its own
// version of every dep + each tells a complete story when read in
// isolation. The trade-off is duplication: when an upstream fix
// applies to all three, you change it three times.
//
// If a true cross-app library re-emerges in the future, factor it
// back out via a fresh path-dep. Don't try to keep this file in
// sync with sales_app/shared.dart manually — it WILL drift.

// ---- Core ----
export 'core/api/api_client.dart';
export 'core/di/injector.dart';
export 'core/errors/api_exception.dart';
export 'core/storage/token_storage.dart';
export 'core/theme/app_theme.dart';

// ---- Auth feature ----
export 'auth/data/auth_api.dart';
export 'auth/domain/auth_repository.dart';
export 'auth/domain/auth_user.dart';
export 'auth/presentation/bloc/auth_bloc.dart';
export 'auth/presentation/pages/home_page.dart';
export 'auth/presentation/pages/login_page.dart';

// ---- Router helpers ----
export 'router/auth_guard.dart';
export 'router/router_transitions.dart';

// ---- Uploads gateway + KTP OCR client ----
export 'uploads/uploads_gateway.dart';

// ---- GPS helper ----
export 'gps/gps.dart';

// ---- Customer portal deep-link ----
export 'portal/portal_link.dart';

// ---- Push notifications scaffold (kill-switched by ION_PUSH_ENABLED) ----
export 'push/push_notifier.dart';

// ---- Design-system widgets ----
export 'widgets/ion_app_bar.dart';
export 'widgets/ion_form.dart';
export 'widgets/ion_anim.dart';
