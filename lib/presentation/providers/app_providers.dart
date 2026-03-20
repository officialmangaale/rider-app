import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/services/app_preferences.dart';
import '../../core/services/map_launcher_service.dart';
import '../../data/datasources/asset_mock_data_source.dart';
import '../../data/repositories/api_rider_repository.dart';
import '../../data/services/rider_backend_api.dart';
import '../../domain/entities/app_models.dart';
import '../../domain/repositories/rider_repository.dart';
import '../../core/network/platform_http_client.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences override is required.'),
);

final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);

final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

final assetMockDataSourceProvider = Provider<AssetMockDataSource>(
  (ref) => AssetMockDataSource(ref.watch(assetBundleProvider)),
);

final platformHttpClientProvider = Provider<PlatformHttpClient>(
  (ref) => createPlatformHttpClient(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
    httpClient: ref.watch(platformHttpClientProvider),
    tokenStore: ref.watch(appPreferencesProvider),
  ),
);

final riderBackendApiProvider = Provider<RiderBackendApi>(
  (ref) => RiderBackendApi(ref.watch(apiClientProvider)),
);

final riderRepositoryProvider = Provider<RiderRepository>(
  (ref) => ApiRiderRepository(
    api: ref.watch(riderBackendApiProvider),
    preferences: ref.watch(appPreferencesProvider),
    assetMockDataSource: ref.watch(assetMockDataSourceProvider),
  ),
);

final mapLauncherServiceProvider = Provider<MapLauncherService>(
  (ref) => PlaceholderMapLauncherService(),
);

class ThemeModeController extends Notifier<ThemeMode> {
  late final AppPreferences _preferences;

  @override
  ThemeMode build() {
    _preferences = ref.read(appPreferencesProvider);
    return _preferences.getThemeMode();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = mode;
    await _preferences.setThemeMode(mode);
  }

  Future<void> toggle() {
    return updateThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class SessionState {
  const SessionState({
    required this.hasSeenOnboarding,
    required this.isAuthenticated,
  });

  final bool hasSeenOnboarding;
  final bool isAuthenticated;

  SessionState copyWith({bool? hasSeenOnboarding, bool? isAuthenticated}) {
    return SessionState(
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class SessionController extends Notifier<SessionState> {
  late final AppPreferences _preferences;
  late final RiderRepository _repository;

  @override
  SessionState build() {
    _preferences = ref.read(appPreferencesProvider);
    _repository = ref.read(riderRepositoryProvider);
    return SessionState(
      hasSeenOnboarding: _preferences.hasSeenOnboarding,
      isAuthenticated: _preferences.isAuthenticated,
    );
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(hasSeenOnboarding: true);
    await _preferences.setHasSeenOnboarding(true);
  }

  Future<void> loginWithPassword({
    required String login,
    required String password,
  }) async {
    await _repository.loginWithPassword(login: login, password: password);
    state = state.copyWith(isAuthenticated: true);
    ref.invalidate(riderHubControllerProvider);
  }

  Future<AuthOtpChallenge> sendLoginOtp({required String login}) {
    return _repository.sendLoginOtp(login: login);
  }

  Future<void> verifyLoginOtp({
    required String login,
    required String otp,
  }) async {
    await _repository.verifyLoginOtp(login: login, otp: otp);
    state = state.copyWith(isAuthenticated: true);
    ref.invalidate(riderHubControllerProvider);
  }

  Future<AuthOtpChallenge> requestPasswordReset({required String login}) {
    return _repository.requestPasswordReset(login: login);
  }

  Future<void> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  }) {
    return _repository.resetPassword(
      login: login,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = state.copyWith(isAuthenticated: false);
    ref.invalidate(riderHubControllerProvider);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class RiderHubController extends AsyncNotifier<RiderHubState> {
  late final RiderRepository _repository;

  @override
  Future<RiderHubState> build() async {
    _repository = ref.read(riderRepositoryProvider);
    return _repository.bootstrap();
  }

  Future<void> refreshHub() async {
    state = const AsyncLoading<RiderHubState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_repository.bootstrap);
  }

  Future<void> acceptOrder(String assignmentId) {
    return _runMutation(() => _repository.acceptOrder(assignmentId));
  }

  Future<void> rejectOrder(String assignmentId, {String? reason}) {
    return _runMutation(
      () => _repository.rejectOrder(assignmentId, reason: reason),
    );
  }

  Future<void> setAvailabilityStatus(AvailabilityStatus status) {
    return _runMutation(() => _repository.setAvailabilityStatus(status));
  }

  Future<void> markNotificationRead(String id) {
    return _runMutation(() => _repository.markNotificationRead(id));
  }

  Future<void> markAllNotificationsRead() {
    return _runMutation(_repository.markAllNotificationsRead);
  }

  Future<void> advanceActiveOrder({String? otp}) async {
    final order = state.valueOrNull?.activeOrder;
    if (order == null) {
      return;
    }
    await _runMutation(() => _repository.advanceActiveOrder(order, otp: otp));
  }

  Future<void> _runMutation(Future<void> Function() mutation) async {
    final previous = state.valueOrNull;
    try {
      await mutation();
      final next = await _repository.bootstrap();
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }
}

final riderHubControllerProvider =
    AsyncNotifierProvider<RiderHubController, RiderHubState>(
      RiderHubController.new,
    );

final riderHubStateProvider = Provider<RiderHubState?>(
  (ref) => ref.watch(riderHubControllerProvider).valueOrNull,
);

final unreadNotificationsCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(riderHubStateProvider)
          ?.notifications
          .where((item) => item.isUnread)
          .length ??
      0,
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(ref);
});
