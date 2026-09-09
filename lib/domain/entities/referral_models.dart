/// Rider-side models for the unified referral programme
/// (restaurant-service `internal/referralcore`, migrations 088/089).
///
/// Money crosses the wire as integer milli-rupees, matching the backend
/// ledger. It is converted to rupees only for display, so no rounding error
/// can creep into a value the rider is told they earned.
library;

/// A rider's referral screen, as the backend describes it.
class RiderReferralDashboard {
  const RiderReferralDashboard({
    required this.enabled,
    required this.code,
    required this.shareLink,
    required this.shareMessage,
    required this.rewardSummary,
    required this.rewardMillis,
    required this.pendingCount,
    required this.qualifiedCount,
    required this.rewardedCount,
    required this.totalEarnedMillis,
    required this.availableRewardMillis,
    required this.referrals,
  });

  /// False when the programme is switched off in the admin panel. The code is
  /// still shown so links a rider already shared keep resolving, but the
  /// screen must not promise a bonus while it is off.
  final bool enabled;

  final String code;
  final String shareLink;

  /// Share text built server-side, so the bonus quoted in a WhatsApp message
  /// can never disagree with the amount the admin panel is configured to pay.
  final String shareMessage;

  /// e.g. "₹300 bonus" — also built server-side.
  final String rewardSummary;

  final int rewardMillis;
  final int pendingCount;
  final int qualifiedCount;
  final int rewardedCount;
  final int totalEarnedMillis;
  final int availableRewardMillis;
  final List<RiderReferralEntry> referrals;

  static const empty = RiderReferralDashboard(
    enabled: false,
    code: '',
    shareLink: '',
    shareMessage: '',
    rewardSummary: '',
    rewardMillis: 0,
    pendingCount: 0,
    qualifiedCount: 0,
    rewardedCount: 0,
    totalEarnedMillis: 0,
    availableRewardMillis: 0,
    referrals: <RiderReferralEntry>[],
  );

  factory RiderReferralDashboard.fromJson(Map<String, dynamic> json) {
    final rawReferrals = json['referrals'];
    return RiderReferralDashboard(
      enabled: _asBool(json['enabled']),
      code: _asString(json['code']),
      shareLink: _asString(json['share_link']),
      shareMessage: _asString(json['share_message']),
      rewardSummary: _asString(json['reward_summary']),
      rewardMillis: _asInt(json['reward_millis']),
      pendingCount: _asInt(json['pending_count']),
      qualifiedCount: _asInt(json['qualified_count']),
      rewardedCount: _asInt(json['rewarded_count']),
      totalEarnedMillis: _asInt(json['total_earned_millis']),
      availableRewardMillis: _asInt(json['available_reward_millis']),
      referrals: rawReferrals is List
          ? rawReferrals
                .whereType<Map>()
                .map(
                  (e) => RiderReferralEntry.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false)
          : const <RiderReferralEntry>[],
    );
  }

  bool get hasReferrals => referrals.isNotEmpty;
}

/// One rider this rider referred. Identified only by a masked name — a
/// referrer can see that their referral converted, not harvest contact
/// details of another rider.
class RiderReferralEntry {
  const RiderReferralEntry({
    required this.referralId,
    required this.status,
    required this.maskedName,
    required this.rewardMillis,
  });

  final int referralId;
  final String status;
  final String maskedName;
  final int rewardMillis;

  factory RiderReferralEntry.fromJson(Map<String, dynamic> json) {
    return RiderReferralEntry(
      referralId: _asInt(json['referral_id']),
      status: _asString(json['status']),
      maskedName: _asString(json['masked_name']),
      rewardMillis: _asInt(json['reward_millis']),
    );
  }

  /// Rider-facing wording for a lifecycle state.
  ///
  /// The raw states are operational vocabulary. `fraud_review` in particular
  /// must never reach the screen: it accuses the rider of something, when in
  /// practice it usually means a shared phone or device needs a human look.
  String get label => switch (status) {
    'pending' => 'Completing their first deliveries',
    'fraud_review' => 'Being reviewed',
    'qualified' || 'reward_pending' => 'Bonus on its way',
    'rewarded' => 'Bonus paid',
    'rejected' => 'Not eligible',
    'expired' => 'Expired',
    'reversed' => 'Reversed',
    _ => 'In progress',
  };

  bool get isPaid => status == 'rewarded';
}

/// Formats integer milli-rupees as rupees for display.
///
/// Whole amounts lose the decimals — a ₹300 bonus should read "₹300", not
/// "₹300.00" — while a part-rupee amount keeps them rather than being
/// silently rounded.
String formatMillis(int millis) {
  final rupees = millis / 1000;
  final text = rupees == rupees.roundToDouble()
      ? rupees.round().toString()
      : rupees.toStringAsFixed(2);
  return '₹$text';
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

String _asString(Object? value) => value == null ? '' : value.toString();

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
