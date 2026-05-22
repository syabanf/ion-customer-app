part of 'auth_bloc.dart';

/// AuthStatus reduces UI gating to a single switch.
enum AuthStatus { unknown, unauthenticated, authenticating, authenticated, error }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.errorMessage,
  });

  const AuthState.unknown() : this();
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticating() : this(status: AuthStatus.authenticating);
  const AuthState.authenticated(AuthSession s)
      : this(status: AuthStatus.authenticated, session: s);
  const AuthState.error(String msg)
      : this(status: AuthStatus.error, errorMessage: msg);

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;

  @override
  List<Object?> get props => [status, session, errorMessage];
}
