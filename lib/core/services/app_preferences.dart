import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';

class AppPreferences implements ApiTokenStore {
  AppPreferences(this._preferences);

  final SharedPreferences _preferences;

  ThemeMode getThemeMode() {
    final value = _preferences.getString(AppConstants.preferencesThemeKey);
    return switch (value) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    return _preferences.setString(AppConstants.preferencesThemeKey, value);
  }

  bool get hasSeenOnboarding =>
      _preferences.getBool(AppConstants.preferencesOnboardingKey) ?? false;

  Future<void> setHasSeenOnboarding(bool value) {
    return _preferences.setBool(AppConstants.preferencesOnboardingKey, value);
  }

  @override
  String? get accessToken =>
      _preferences.getString(AppConstants.preferencesAccessTokenKey);

  @override
  String? get refreshToken =>
      _preferences.getString(AppConstants.preferencesRefreshTokenKey);

  bool get isAuthenticated =>
      (_preferences.getBool(AppConstants.preferencesAuthKey) ?? false) ||
      (accessToken?.isNotEmpty ?? false);

  Future<void> setAuthenticated(bool value) {
    return _preferences.setBool(AppConstants.preferencesAuthKey, value);
  }

  @override
  Future<String> getDeviceId() async {
    final existing = _preferences.getString(AppConstants.preferencesDeviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated =
        'flutter-rider-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    await _preferences.setString(AppConstants.preferencesDeviceIdKey, generated);
    return generated;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _preferences.setString(
      AppConstants.preferencesAccessTokenKey,
      accessToken,
    );
    await _preferences.setString(
      AppConstants.preferencesRefreshTokenKey,
      refreshToken,
    );
    await setAuthenticated(true);
  }

  @override
  Future<void> clearTokens() async {
    await _preferences.remove(AppConstants.preferencesAccessTokenKey);
    await _preferences.remove(AppConstants.preferencesRefreshTokenKey);
    await setAuthenticated(false);
  }
}
