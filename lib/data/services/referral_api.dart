import '../../core/network/api_client.dart';
import '../../domain/entities/referral_models.dart';

/// The rider referral programme, served by restaurant-service rather than
/// rider-service.
///
/// It gets its own [ApiClient] because the base URL differs; the token store
/// is shared, so the rider's existing session is reused and there is no second
/// login. See `referralProvider` for the wiring.
class ReferralApi {
  const ReferralApi(this._client);

  final ApiClient _client;

  /// The rider programme. The customer and restaurant programmes are served by
  /// the same endpoints under a different path segment and are never requested
  /// from this app.
  static const String program = 'rider_referral';

  /// POST /referrals/rider_referral/apply
  ///
  /// Attributes this rider to the code's owner. Authenticated, which is why a
  /// code followed from a link has to wait until signup completes.
  ///
  /// A rejected code comes back as `applied: false` with a message written for
  /// the rider — a 200, not an error — so the caller distinguishes "that code
  /// was refused" from "the request failed".
  Future<bool> applyCode(String code) async {
    final response = await _client.postObject(
      '/referrals/$program/apply',
      body: <String, dynamic>{'code': code},
    );
    final applied = response.data['applied'];
    return applied is bool ? applied : false;
  }

  /// GET /referrals/rider_referral/me
  Future<RiderReferralDashboard> fetchDashboard() async {
    final response = await _client.getObject('/referrals/$program/me');
    return RiderReferralDashboard.fromJson(response.data);
  }
}
