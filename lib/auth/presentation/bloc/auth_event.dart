part of 'auth_bloc.dart';

/// Events drive the [AuthBloc] state machine. Keep them coarse — one event
/// per user intent, not per UI tap. The widgets are dumb; the BLoC owns
/// the rules.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// Fired on app start. Asks the bloc to restore a session from storage.
class AuthRestoreRequested extends AuthEvent {
  const AuthRestoreRequested();
}

/// User submitted the login form.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// User tapped sign-out.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// The ApiClient's refresh hook failed, so the user must be signed out
/// involuntarily. The DI wiring connects ApiClient.onAuthLost → this event.
class AuthSessionLost extends AuthEvent {
  const AuthSessionLost();
}
