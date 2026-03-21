import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../domain/entities/app_models.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, unauthenticated, authenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.hasSeenOnboarding = false,
  });

  final AuthStatus status;
  final bool hasSeenOnboarding;

  SessionState copyWith({AuthStatus? status, bool? hasSeenOnboarding}) {
    return SessionState(
      status: status ?? this.status,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
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
    return SessionState(
      status: hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      hasSeenOnboarding: prefs.hasSeenOnboarding,
    );
  }

  void markOnboardingComplete() {
    ref.read(appPreferencesProvider).setOnboardingSeen();
    state = state.copyWith(hasSeenOnboarding: true);
  }

  Future<AuthOtpChallenge> sendOtp({required String login}) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.sendLoginOtp(login: login);
    return AuthOtpChallenge(
      expiresInSeconds: (envelope.data['expires_in'] as num?)?.toInt() ?? 300,
      channel: envelope.data['channel'] as String? ?? 'SMS',
    );
  }

  Future<void> verifyOtp({
    required String login,
    required String otp,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.verifyLoginOtp(login: login, otp: otp);
    await _handleAuthTokens(envelope.data);
  }

  Future<void> loginWithPassword({
    required String login,
    required String password,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.loginWithPassword(
      login: login,
      password: password,
    );
    await _handleAuthTokens(envelope.data);
  }

  Future<void> signup({
    required String name,
    required String phone,
    required String city,
    required String email,
    required String vehicleType,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.auth.signup(payload: {
      'name': name,
      'phone': phone,
      'city': city,
      'email': email,
      'vehicle_type': vehicleType,
    });
    await _handleAuthTokens(envelope.data);
  }

  Future<AuthOtpChallenge> requestPasswordReset({
    required String login,
  }) async {
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
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  Future<void> _handleAuthTokens(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken != null && accessToken.isNotEmpty) {
      await ref.read(appPreferencesProvider).saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
      );
      state = state.copyWith(status: AuthStatus.authenticated);
    }
  }
}
