import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/platform_http_client.dart';
import '../../data/services/referral_api.dart';
import '../../domain/entities/referral_models.dart';
import 'core_providers.dart';

/// A second [ApiClient] aimed at restaurant-service, which hosts the unified
/// referral programme.
///
/// It shares [AppPreferences] as its token store, so the rider's existing
/// access token is sent and refreshed exactly as it is for rider-service — the
/// two services validate against the same shared JWT secret.
///
/// `onUnauthorized` is deliberately not wired here. A 401 from the referral
/// service is reported on the referral screen and nowhere else; it must never
/// log a rider out mid-delivery.
final restaurantApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConstants.restaurantApiBaseUrl,
    httpClient: createPlatformHttpClient(),
    tokenStore: ref.watch(appPreferencesProvider),
  );
});

final referralApiProvider = Provider<ReferralApi>((ref) {
  return ReferralApi(ref.watch(restaurantApiClientProvider));
});

/// The rider's referral dashboard.
///
/// Not `autoDispose`: the screen is reachable from Profile and a rider may
/// leave it while the share sheet is open, and a provider torn down at an
/// async gap would drop the result of an in-flight request.
final referralControllerProvider =
    AsyncNotifierProvider<ReferralController, RiderReferralDashboard>(
      ReferralController.new,
    );

class ReferralController extends AsyncNotifier<RiderReferralDashboard> {
  @override
  Future<RiderReferralDashboard> build() {
    return ref.read(referralApiProvider).fetchDashboard();
  }

  /// Pull-to-refresh. Keeps the previous dashboard visible while reloading so
  /// the screen does not flash empty, and surfaces a failure as an error state
  /// rather than swallowing it.
  Future<void> refresh() async {
    state = AsyncValue<RiderReferralDashboard>.loading()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(referralApiProvider).fetchDashboard(),
    );
  }
}
