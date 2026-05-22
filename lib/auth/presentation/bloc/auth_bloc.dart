import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/api_exception.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Owns authentication state for the entire app.
///
/// Provided once at the root of the widget tree. The GoRouter redirect
/// reads `state.status` to enforce protected routes; widgets read the
/// `session` to gate UI by role / permission.
///
/// Optional [roleFilter] lets each binary refuse logins from users
/// whose roles don't fit the binary's purpose. The Sales App passes a
/// filter that accepts only sales roles; the Tech App passes one for
/// technician roles. When a session fails the filter we log it out and
/// emit an error so the LoginPage can surface a friendly message.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._repo, {
    this.roleFilter,
    this.roleFilterErrorMessage =
        'This account does not have access to this app.',
  }) : super(const AuthState.unknown()) {
    on<AuthRestoreRequested>(_onRestore);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionLost>(_onSessionLost);
  }

  final AuthRepository _repo;

  /// Returns true when [session] is allowed to use this app. When null
  /// (the default), every authenticated user passes.
  final bool Function(AuthSession session)? roleFilter;

  /// Message shown to the user when [roleFilter] rejects them. Override
  /// per app for a tailored copy ("Sales reps only", "Technicians only", …).
  final String roleFilterErrorMessage;

  bool _passes(AuthSession s) => roleFilter == null || roleFilter!(s);

  Future<void> _onRestore(AuthRestoreRequested event, Emitter<AuthState> emit) async {
    try {
      final session = await _repo.restore();
      if (session == null) {
        emit(const AuthState.unauthenticated());
        return;
      }
      if (!_passes(session)) {
        // Stale session from another app on the same device — purge.
        await _repo.logout();
        emit(AuthState.error(roleFilterErrorMessage));
        return;
      }
      emit(AuthState.authenticated(session));
    } on ApiException catch (e) {
      // Network failure on app start — treat as unauthenticated so the
      // user lands on login rather than a wedged splash screen.
      emit(AuthState.error(e.message));
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.authenticating());
    try {
      final session = await _repo.login(email: event.email, password: event.password);
      if (!_passes(session)) {
        // Tokens were issued but this user can't use this binary.
        // Clear them so a subsequent restore doesn't loop.
        await _repo.logout();
        emit(AuthState.error(roleFilterErrorMessage));
        return;
      }
      emit(AuthState.authenticated(session));
    } on ApiException catch (e) {
      emit(AuthState.error(e.message));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(const AuthState.unauthenticated());
  }

  Future<void> _onSessionLost(AuthSessionLost event, Emitter<AuthState> emit) async {
    // Triggered by ApiClient.onAuthLost when refresh fails irrecoverably.
    emit(const AuthState.unauthenticated());
  }
}
