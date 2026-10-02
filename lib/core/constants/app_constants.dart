class AppConstants {
  const AppConstants._();

  static const appName = 'Mangaale Express';
  static const appTagline = 'Fast line delivery for your culinary favorites';
  // Server origins. The defaults are production; override per build, for a test
  // environment, with e.g. --dart-define=RIDER_API_BASE_URL=https://rider-stage.example.com
  static const apiBaseUrl = String.fromEnvironment(
    'RIDER_API_BASE_URL',
    defaultValue: 'https://rider-prod.mangaale.com',
  );
  static const riderWsUrl = String.fromEnvironment(
    'RIDER_WS_URL',
    defaultValue: 'wss://rider-prod.mangaale.com/ws/rider',
  );
  static const userApiBaseUrl = String.fromEnvironment(
    'USER_API_BASE_URL',
    defaultValue: 'https://user-prod.mangaale.com',
  );

  /// restaurant-service hosts the unified referral programme
  /// (`/referrals/rider_referral/...`). Riders authenticate against the
  /// same shared JWT_SECRET, so the access token issued at login is
  /// accepted here without a second sign-in.
  static const restaurantApiBaseUrl = String.fromEnvironment(
    'RESTAURANT_API_BASE_URL',
    defaultValue: 'https://restaurant-prod.mangaale.com',
  );
  static const requestIdPrefix = 'frontend-flutter-rider';
  static const preferencesThemeKey = 'theme_mode';
  static const preferencesOnboardingKey = 'has_seen_onboarding';
  static const preferencesAuthKey = 'is_authenticated';
  static const preferencesAccessTokenKey = 'access_token';
  static const preferencesRefreshTokenKey = 'refresh_token';
  static const preferencesAuthRoleKey = 'auth_role';
  static const preferencesDeviceIdKey = 'device_id';
  /// Referral code captured from a link before the rider had an account,
  /// with the moment it was captured so it can be expired.
  static const preferencesPendingReferralCodeKey = 'pending_referral_code';
  static const preferencesPendingReferralAtKey = 'pending_referral_captured_at';
  static const mockRefreshDelayMs = 900;

}
