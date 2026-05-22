import 'dart:async';

import 'package:dio/dio.dart';

import '../errors/api_exception.dart';
import '../storage/token_storage.dart';

/// ApiClient wraps Dio with project-standard behavior:
///
///   - Attaches the access token to every request.
///   - On 401, attempts ONE refresh-and-retry (single-flight; concurrent
///     401s share the same in-flight refresh).
///   - Translates Dio errors to ApiException so BLoCs depend on the
///     domain error model, not the HTTP transport.
///
/// Constructed once in DI (see core/di/injector.dart) and shared across
/// repositories.
class ApiClient {
  ApiClient({
    required this.dio,
    required this.tokens,
    required this.baseUrl,
  }) {
    dio.options.baseUrl = baseUrl;
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 20);
    dio.interceptors.add(_AuthInterceptor(this));
  }

  final Dio dio;
  final TokenStorage tokens;
  final String baseUrl;

  /// In-flight refresh future, if any. Shared across concurrent callers
  /// so the API isn't hammered by simultaneous 401s.
  Future<String?>? _refreshing;

  /// External hook the AuthRepository sets so the interceptor can call
  /// the refresh endpoint without depending on the auth feature directly.
  /// Avoids a circular import between core/api and features/auth.
  Future<String?> Function(String refreshToken)? refreshHandler;

  /// Called when refresh fails irrecoverably — wire to a "force logout"
  /// signal in the AuthBloc.
  void Function()? onAuthLost;

  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool skipAuth = false,
  }) async {
    try {
      final opts = (options ?? Options()).copyWith(extra: {
        ...?options?.extra,
        if (skipAuth) _skipAuthFlag: true,
      });
      return await dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: opts,
      );
    } on DioException catch (e) {
      throw _toApi(e);
    }
  }

  ApiException _toApi(DioException e) {
    final resp = e.response;
    if (resp != null) {
      final body = resp.data;
      Map<String, dynamic>? map;
      if (body is Map<String, dynamic>) map = body;
      return ApiException.fromResponse(statusCode: resp.statusCode ?? 0, body: map);
    }
    return ApiException.network(e.message ?? e.error ?? 'unknown');
  }

  Future<String?> _refresh() {
    final existing = _refreshing;
    if (existing != null) return existing;

    final future = () async {
      try {
        final refreshToken = await tokens.readRefresh();
        if (refreshToken == null) return null;
        final handler = refreshHandler;
        if (handler == null) return null;
        final newAccess = await handler(refreshToken);
        if (newAccess == null) {
          await tokens.clear();
          onAuthLost?.call();
        }
        return newAccess;
      } finally {
        _refreshing = null;
      }
    }();

    _refreshing = future;
    return future;
  }

  static const _skipAuthFlag = 'ion.skipAuth';
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[ApiClient._skipAuthFlag] != true) {
      final access = await _client.tokens.readAccess();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final resp = err.response;
    final isUnauth = resp?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['ion.retried'] == true;

    if (!isUnauth || alreadyRetried) {
      handler.next(err);
      return;
    }

    final newAccess = await _client._refresh();
    if (newAccess == null) {
      handler.next(err);
      return;
    }

    // Retry the original request with the fresh token.
    final retryOpts = err.requestOptions;
    retryOpts.headers['Authorization'] = 'Bearer $newAccess';
    retryOpts.extra['ion.retried'] = true;

    try {
      final response = await _client.dio.fetch<dynamic>(retryOpts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
