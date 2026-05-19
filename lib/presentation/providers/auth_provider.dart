import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/app_routes.dart';
import '../../domain/entities/app_models.dart';
import '../../features/delivery/providers/rider_delivery_provider.dart';
import '../../features/restaurant_rider/providers/restaurant_rider_provider.dart';
import 'availability_provider.dart';
import 'core_providers.dart';
import 'delivery_provider.dart';
import 'earnings_provider.dart';
import 'notifications_provider.dart';
import 'orders_provider.dart';
import 'profile_provider.dart';
import 'rider_compliance_provider.dart';

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, unauthenticated, authenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.hasSeenOnboarding = false,
    this.role,
  });

  final AuthStatus status;
  final bool hasSeenOnboarding;
  final String? role;

  SessionState copyWith({
    AuthStatus? status,
    bool? hasSeenOnboarding,
    String? role,
    bool clearRole = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      role: clearRole ? null : role ?? this.role,
    );
  }
}

// ---------------------------------------------------------------------------
// Session controller
// ---------------------------------------------------------------------------

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final prefs = ref.watch(appPreferencesProvider);
    final hasToken = (prefs.accessToken ?? '').isNotEmpty;
    final rawRole = prefs.rawAuthRole;
    final normalizedRole = AppRoutes.normalizeRole(rawRole);
    _debugSessionRole(
      source: 'session_build',
      rawRole: rawRole,
      normalizedRole: normalizedRole,
    );
    return SessionState(
      status: hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      hasSeenOnboarding: prefs.hasSeenOnboarding,
      role: normalizedRole,
    );
  }

  void markOnboardingComplete() {
    ref.read(appPreferencesProvider).setOnboardingSeen();
    state = state.copyWith(hasSeenOnboarding: true);
    ref.read(appRouterRefreshProvider).refresh();
  }

  Future<AuthOtpChallenge> sendOtp({required String login}) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.sendLoginOtp(login: login);
    return AuthOtpChallenge(
      expiresInSeconds: (envelope.data['expires_in'] as num?)?.toInt() ?? 300,
      channel: envelope.data['channel'] as String? ?? 'SMS',
    );
  }

  Future<void> verifyOtp({required String login, required String otp}) async {
    final api = ref.read(riderBackendApiProvider);
    final preferences = ref.read(appPreferencesProvider);
    final envelope = await api.auth.verifyLoginOtp(
      login: login,
      otp: otp,
      deviceId: await preferences.getDeviceId(),
      deviceName: _deviceName,
    );
    await _handleAuthResponse(envelope, source: 'otp_login');
  }

  Future<void> loginWithPassword({
    required String login,
    required String password,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    final preferences = ref.read(appPreferencesProvider);
    final envelope = await api.auth.loginWithPassword(
      login: login,
      password: password,
      deviceId: await preferences.getDeviceId(),
      deviceName: _deviceName,
    );
    await _handleAuthResponse(envelope, source: 'password_login');
  }

  Future<void> signup({
    required String firstName,
    required String lastName,
    required String password,
    required String licenseNumber,
    required String phone,
    required String city,
    required String email,
    required String vehicleType,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.signup(
      payload: {
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
        'license_number': licenseNumber,
        'phone': phone,
        'city': city,
        'email': email,
        'vehicle_type': vehicleType,
        'primary_role': 'delivery_driver',
      },
    );
    await _handleAuthResponse(
      envelope,
      source: 'signup',
      fallbackRole: 'delivery_driver',
    );
  }

  Future<AuthOtpChallenge> requestPasswordReset({required String login}) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.requestPasswordReset(login: login);
    return AuthOtpChallenge(
      expiresInSeconds: (envelope.data['expires_in'] as num?)?.toInt() ?? 300,
      channel: envelope.data['channel'] as String? ?? 'SMS',
    );
  }

  Future<void> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    await api.auth.resetPassword(
      login: login,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    try {
      final api = ref.read(riderBackendApiProvider);
      await api.auth.logout();
    } on ApiException catch (_) {
      // Best-effort logout — clear tokens even if server call fails.
    }
    await ref.read(appPreferencesProvider).clearTokens();
    _clearUserScopedState(disconnectRealtime: true);
    state = state.copyWith(status: AuthStatus.unauthenticated, clearRole: true);
    ref.read(appRouterRefreshProvider).refresh();
  }

  Future<void> _handleAuthResponse(
    ApiEnvelope<Map<String, dynamic>> envelope, {
    required String source,
    String? fallbackRole,
  }) async {
    _clearUserScopedState(disconnectRealtime: true);

    final data = _authPayload(envelope);
    final parsedRawRole = AppRoutes.extractRawRole(data);
    final role =
        AppRoutes.normalizeRole(parsedRawRole) ??
        AppRoutes.normalizeRole(fallbackRole);
    final accessToken = _extractAccessToken(data, envelope.raw);
    final refreshToken = _extractRefreshToken(data, envelope.raw);

    _debugAuth(
      'Auth response source=$source status=${envelope.statusCode ?? 'unknown'} '
      'dataKeys=${data.keys.join(',')} rawKeys=${envelope.raw.keys.join(',')} '
      'tokenFound=${accessToken == null ? 'no' : 'yes'} '
      'rawRole=${parsedRawRole ?? fallbackRole ?? 'missing'} normalizedRole=${role ?? 'missing'}',
    );

    if (role == null || !AppRoutes.isSupportedRiderRole(role)) {
      throw const ApiException(
        message: 'This app is only for riders.',
        errorCode: 'UNAUTHORIZED_ROLE',
      );
    }

    if (accessToken == null) {
      throw ApiException(
        message: 'Authentication token is missing from the login response.',
        errorCode: 'TOKEN_MISSING',
        statusCode: envelope.statusCode,
        rawData: envelope.raw,
      );
    }

    final preferences = ref.read(appPreferencesProvider);
    await preferences.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken ?? '',
    );
    await preferences.setAuthRole(role);

    final storedAccessToken = preferences.accessToken;
    final storedRefreshToken = preferences.refreshToken;
    final storedRole = AppRoutes.normalizeRole(preferences.authRole);
    _debugSessionRole(
      source: 'auth_save',
      rawRole: preferences.rawAuthRole,
      normalizedRole: storedRole,
    );
    final refreshSaved =
        refreshToken == null || refreshToken == storedRefreshToken;
    if (storedAccessToken != accessToken ||
        !refreshSaved ||
        storedRole != role) {
      await preferences.clearTokens();
      throw ApiException(
        message: 'Could not save your login session. Please try again.',
        errorCode: 'SESSION_SAVE_FAILED',
        statusCode: envelope.statusCode,
      );
    }

    state = state.copyWith(status: AuthStatus.authenticated, role: role);
    _clearUserScopedState(disconnectRealtime: false);
    ref.read(appRouterRefreshProvider).refresh();
    _debugAuth('Auth session saved source=$source normalizedRole=$role');
  }

  void _clearUserScopedState({required bool disconnectRealtime}) {
    if (disconnectRealtime) {
      ref.read(riderDeliveryControllerProvider.notifier).clearSession();
    }

    ref.invalidate(riderDeliveryControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(riderComplianceControllerProvider);
    ref.invalidate(ordersControllerProvider);
    ref.invalidate(deliveryControllerProvider);
    ref.invalidate(earningsControllerProvider);
    ref.invalidate(notificationsControllerProvider);
    ref.invalidate(availabilityControllerProvider);
    ref.invalidate(activeOrdersProvider);
    ref.invalidate(deliveredOrdersProvider);
    ref.invalidate(linkedRestaurantsProvider);
    ref.invalidate(riderSocketServiceProvider);
    ref.invalidate(riderLocationServiceProvider);
  }

  Map<String, dynamic> _authPayload(
    ApiEnvelope<Map<String, dynamic>> envelope,
  ) {
    if (envelope.data.isNotEmpty) {
      return envelope.data;
    }
    final rawData = _asMap(envelope.raw['data']);
    if (rawData.isNotEmpty) {
      return rawData;
    }
    return envelope.raw;
  }

  String? _extractAccessToken(
    Map<String, dynamic> data,
    Map<String, dynamic> raw,
  ) {
    final tokens = _asMap(data['tokens']);
    final rawData = _asMap(raw['data']);
    final rawTokens = _asMap(rawData['tokens']);
    return _firstNonEmptyString([
      _stringOrNull(tokens['access_token']),
      _stringOrNull(tokens['accessToken']),
      _stringOrNull(tokens['authToken']),
      _stringOrNull(data['access_token']),
      _stringOrNull(data['accessToken']),
      _stringOrNull(data['authToken']),
      _stringOrNull(data['token']),
      _stringOrNull(data['jwt']),
      _stringOrNull(rawTokens['access_token']),
      _stringOrNull(rawTokens['accessToken']),
      _stringOrNull(rawTokens['authToken']),
      _stringOrNull(raw['access_token']),
      _stringOrNull(raw['accessToken']),
      _stringOrNull(raw['authToken']),
    ]);
  }

  String? _extractRefreshToken(
    Map<String, dynamic> data,
    Map<String, dynamic> raw,
  ) {
    final tokens = _asMap(data['tokens']);
    final rawData = _asMap(raw['data']);
    final rawTokens = _asMap(rawData['tokens']);
    return _firstNonEmptyString([
      _stringOrNull(tokens['refresh_token']),
      _stringOrNull(tokens['refreshToken']),
      _stringOrNull(data['refresh_token']),
      _stringOrNull(data['refreshToken']),
      _stringOrNull(rawTokens['refresh_token']),
      _stringOrNull(rawTokens['refreshToken']),
      _stringOrNull(raw['refresh_token']),
      _stringOrNull(raw['refreshToken']),
    ]);
  }

  String? _firstNonEmptyString(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _stringOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return const <String, dynamic>{};
  }

  String get _deviceName {
    if (kIsWeb) {
      return 'Flutter Web Rider';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Flutter Android Rider',
      TargetPlatform.iOS => 'Flutter iPhone Rider',
      TargetPlatform.macOS => 'Flutter macOS Rider',
      TargetPlatform.windows => 'Flutter Windows Rider',
      TargetPlatform.linux => 'Flutter Linux Rider',
      TargetPlatform.fuchsia => 'Flutter Fuchsia Rider',
    };
  }

  void _debugAuth(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }

  void _debugSessionRole({
    required String source,
    required String? rawRole,
    required String? normalizedRole,
  }) {
    assert(() {
      debugPrint(
        'Auth role normalized source=$source rawRole=${rawRole ?? 'missing'} '
        'normalizedRole=${normalizedRole ?? 'missing'}',
      );
      return true;
    }());
  }
}
