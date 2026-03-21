import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/platform_http_client.dart';
import '../../core/router/app_router.dart';
import '../../core/services/app_preferences.dart';
import '../../core/services/map_launcher_service.dart';
import '../../data/services/rider_backend_api.dart';

// ---------------------------------------------------------------------------
// Foundation providers — SharedPreferences, ApiClient, Backend API
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override sharedPreferencesProvider in ProviderScope',
  ),
);

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences(ref.watch(sharedPreferencesProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  return ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
    httpClient: createPlatformHttpClient(),
    tokenStore: prefs,
  );
});

final riderBackendApiProvider = Provider<RiderBackendApi>((ref) {
  return RiderBackendApi(ref.watch(apiClientProvider));
});

final mapLauncherServiceProvider = Provider<MapLauncherService>((ref) {
  return PlaceholderMapLauncherService();
});

// ---------------------------------------------------------------------------
// Theme mode controller — persisted to SharedPreferences
// ---------------------------------------------------------------------------

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(appPreferencesProvider);
    return prefs.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    ref.read(appPreferencesProvider).setDarkMode(next == ThemeMode.dark);
    state = next;
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(ref);
});
