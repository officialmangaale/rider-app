import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Settings provider — persisted to SharedPreferences.
// ---------------------------------------------------------------------------

class AppSettings {
  const AppSettings({
    this.orderAlerts = true,
    this.promotions = true,
    this.privacyMode = false,
    this.themeMode = ThemeMode.light,
  });

  final bool orderAlerts;
  final bool promotions;
  final bool privacyMode;
  final ThemeMode themeMode;

  AppSettings copyWith({
    bool? orderAlerts,
    bool? promotions,
    bool? privacyMode,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      orderAlerts: orderAlerts ?? this.orderAlerts,
      promotions: promotions ?? this.promotions,
      privacyMode: privacyMode ?? this.privacyMode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  static const _keyOrderAlerts = 'settings_order_alerts';
  static const _keyPromotions = 'settings_promotions';
  static const _keyPrivacyMode = 'settings_privacy_mode';

  @override
  AppSettings build() {
    final prefs = ref.watch(appPreferencesProvider);
    final sp = prefs.prefs;
    return AppSettings(
      orderAlerts: sp.getBool(_keyOrderAlerts) ?? true,
      promotions: sp.getBool(_keyPromotions) ?? true,
      privacyMode: sp.getBool(_keyPrivacyMode) ?? false,
      themeMode: prefs.isDarkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setOrderAlerts(bool value) {
    ref.read(appPreferencesProvider).prefs.setBool(_keyOrderAlerts, value);
    state = state.copyWith(orderAlerts: value);
  }

  void setPromotions(bool value) {
    ref.read(appPreferencesProvider).prefs.setBool(_keyPromotions, value);
    state = state.copyWith(promotions: value);
  }

  void setPrivacyMode(bool value) {
    ref.read(appPreferencesProvider).prefs.setBool(_keyPrivacyMode, value);
    state = state.copyWith(privacyMode: value);
  }

  void toggleTheme() {
    ref.read(themeModeControllerProvider.notifier).toggle();
    final next = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    state = state.copyWith(themeMode: next);
  }
}
