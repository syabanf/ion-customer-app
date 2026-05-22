/// ApiException mirrors the backend's error envelope.
///
/// The backend always returns errors as:
///   { "error": { "code": "user.email_taken", "kind": "conflict", "message": "..." } }
///
/// We surface `kind` so BLoCs can react to error categories without
/// brittle code-string matching.
enum ApiErrorKind {
  validation,
  notFound,
  conflict,
  unauthorized,
  forbidden,
  unavailable,
  internal,
  precondition,
  unknown,
}

ApiErrorKind _parseKind(String? raw) {
  switch (raw) {
    case 'validation':
      return ApiErrorKind.validation;
    case 'not_found':
      return ApiErrorKind.notFound;
    case 'conflict':
      return ApiErrorKind.conflict;
    case 'unauthorized':
      return ApiErrorKind.unauthorized;
    case 'forbidden':
      return ApiErrorKind.forbidden;
    case 'unavailable':
      return ApiErrorKind.unavailable;
    case 'internal':
      return ApiErrorKind.internal;
    case 'precondition':
      return ApiErrorKind.precondition;
    default:
      return ApiErrorKind.unknown;
  }
}

class ApiException implements Exception {
  ApiException({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory ApiException.fromResponse({
    required int statusCode,
    required Map<String, dynamic>? body,
  }) {
    final err = body?['error'] as Map<String, dynamic>?;
    return ApiException(
      kind: _parseKind(err?['kind'] as String?),
      code: (err?['code'] as String?) ?? 'http.$statusCode',
      message: (err?['message'] as String?) ?? 'Request failed ($statusCode)',
      statusCode: statusCode,
    );
  }

  factory ApiException.network(Object cause) => ApiException(
        kind: ApiErrorKind.unavailable,
        code: 'network.unreachable',
        message: 'Network unavailable. Check your connection. ($cause)',
      );

  final ApiErrorKind kind;
  final String code;
  final String message;
  final int? statusCode;

  bool get isAuth => kind == ApiErrorKind.unauthorized;

  @override
  String toString() => 'ApiException(kind: $kind, code: $code, message: $message)';
}
