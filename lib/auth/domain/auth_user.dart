import 'package:equatable/equatable.dart';

/// Domain entity for an authenticated user. Mirrors the backend's userDTO
/// but lives in `domain/` because the BLoC depends on this shape, not on
/// the wire model.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.branchId,
    this.branchLevel,
    required this.active,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String phone;
  final String? branchId;
  final String? branchLevel;
  final bool active;

  @override
  List<Object?> get props =>
      [id, employeeId, fullName, email, phone, branchId, branchLevel, active];
}

/// A successful authentication produces this whole bundle. The BLoC's
/// authenticated state carries it; widgets read `roles` and `permissions`
/// for gating without touching repositories directly.
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.roles,
    required this.permissions,
  });

  final AuthUser user;
  final List<String> roles;
  final List<String> permissions;

  bool hasPermission(String key) => permissions.contains(key);
  bool hasAnyPermission(List<String> keys) =>
      keys.any((k) => permissions.contains(k));
  bool hasRole(String role) => roles.contains(role);

  AuthSession copyWith({
    AuthUser? user,
    List<String>? roles,
    List<String>? permissions,
  }) =>
      AuthSession(
        user: user ?? this.user,
        roles: roles ?? this.roles,
        permissions: permissions ?? this.permissions,
      );

  @override
  List<Object?> get props => [user, roles, permissions];
}
