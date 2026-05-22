import 'dart:async';

import 'package:flutter/widgets.dart';

import '../auth/presentation/bloc/auth_bloc.dart';

/// Subscribes to an [AuthBloc] state stream and exposes it as a
/// [Listenable] so go_router can re-evaluate its redirect on every
/// auth state change. Apps construct one of these and pass it to
/// `GoRouter(refreshListenable: ...)`.
class AuthGuardListenable extends ChangeNotifier {
  AuthGuardListenable(this._bloc) {
    _sub = _bloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _bloc;
  late final StreamSubscription<dynamic> _sub;

  /// Returns the redirect target ("/login" / `null`) appropriate for the
  /// given matched location. Pass through your app-specific home so the
  /// auth-success path doesn't have to be hardcoded into the shared lib.
  ///
  /// During the brief window before `AuthRestoreRequested` finishes (or
  /// when storage init failed and the bloc never transitions past
  /// `unknown`), we treat the user as **unauthenticated** rather than
  /// returning `null`. Before Wave 19 we returned `null` here, which
  /// left the user stuck on the auth-gated `initialLocation` (e.g.
  /// `/leads`) showing a blank canvas while the page tried to fetch
  /// data with no token. Now we redirect to `/login` instead — when
  /// the bloc later emits an authenticated state, the second branch
  /// below sends them on to `authedHome`.
  String? redirect({
    required String matchedLocation,
    required String authedHome,
  }) {
    final status = _bloc.state.status;
    final authed = status == AuthStatus.authenticated;
    final onLogin = matchedLocation == '/login';
    if (!authed && !onLogin) return '/login';
    if (authed && onLogin) return authedHome;
    return null;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
