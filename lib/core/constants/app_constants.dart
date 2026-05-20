class AppConstants {
  const AppConstants._();

  static const appName = 'Mangaale Express';
  static const appTagline = 'Fast line delivery for your culinary favorites';
  static const apiBaseUrl = 'https://rider-prod.mangaale.com';
  static const riderWsUrl = 'wss://rider-prod.mangaale.com/ws/rider';
  static const userApiBaseUrl = 'https://user-prod.mangaale.com';
  static const requestIdPrefix = 'frontend-flutter-rider';
  static const preferencesThemeKey = 'theme_mode';
  static const preferencesOnboardingKey = 'has_seen_onboarding';
  static const preferencesAuthKey = 'is_authenticated';
  static const preferencesAccessTokenKey = 'access_token';
  static const preferencesRefreshTokenKey = 'refresh_token';
  static const preferencesAuthRoleKey = 'auth_role';
  static const preferencesDeviceIdKey = 'device_id';
  static const mockRefreshDelayMs = 900;

  // Feature flags
  static const restaurantOwnedRiderMode = true;
}
