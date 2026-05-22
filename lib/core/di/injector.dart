import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../gps/gps.dart';
import '../../uploads/uploads_gateway.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';

/// Service locator. The shared package wires only the cross-cutting
/// dependencies (HTTP client, token storage, auth flow). Each app calls
/// [setupCoreDi] from its `main.dart` and then registers its own feature
/// repos on top with the same `getIt` instance.
final GetIt getIt = GetIt.instance;

/// API base URL. Override via --dart-define=API_URL=https://… at build/run.
const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

/// Per-app role gate. The Sales App passes a filter that accepts sales
/// roles, the Tech App passes one for technician roles. Default null
/// lets any authenticated user in (useful for the legacy combined
/// build and integration tests).
typedef AuthRoleFilter = bool Function(AuthSession session);

Future<void> setupCoreDi({
  AuthRoleFilter? roleFilter,
  String roleFilterErrorMessage =
      'This account does not have access to this app.',
}) async {
  // ---- Core ----
  getIt.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());
  getIt.registerLazySingleton<TokenStorage>(() => TokenStorage(getIt<FlutterSecureStorage>()));
  getIt.registerLazySingleton<Dio>(Dio.new);
  getIt.registerLazySingleton<ApiClient>(() => ApiClient(
        dio: getIt<Dio>(),
        tokens: getIt<TokenStorage>(),
        baseUrl: _apiUrl,
      ));

  // ---- Auth feature ----
  getIt.registerLazySingleton<AuthApi>(() => AuthApi(getIt<ApiClient>()));
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
        api: getIt<AuthApi>(),
        tokens: getIt<TokenStorage>(),
      ));

  // The AuthBloc is a singleton because every part of the app reacts to its
  // state (router, widgets). If we needed per-screen blocs we'd register
  // factory instead.
  getIt.registerLazySingleton<AuthBloc>(() => AuthBloc(
        getIt<AuthRepository>(),
        roleFilter: roleFilter,
        roleFilterErrorMessage: roleFilterErrorMessage,
      ));

  // ---- Uploads + GPS (shared by both apps) ----
  getIt.registerLazySingleton<UploadsGateway>(
      () => UploadsGateway(getIt<ApiClient>()));
  getIt.registerLazySingleton<GpsService>(GpsService.new);

  // Wire the ApiClient's refresh hook to the AuthRepository, and its
  // "auth lost" callback to the AuthBloc. Done here so neither core nor
  // feature packages depend on each other directly.
  final apiClient = getIt<ApiClient>();
  final repo = getIt<AuthRepository>();
  final bloc = getIt<AuthBloc>();
  apiClient.refreshHandler = repo.refreshAccessToken;
  apiClient.onAuthLost = () => bloc.add(const AuthSessionLost());
}
