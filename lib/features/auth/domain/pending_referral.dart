/// Holding a referral code between opening a referral link and finishing
/// signup.
///
/// A referral link is opened by someone who has no account yet, so the code
/// cannot be attributed at the moment it arrives: restaurant-service's
/// `POST /referrals/:program/apply` is authenticated. The code is therefore
/// kept locally until a session exists, then applied once and discarded.
///
/// Pure functions with no storage or plugin dependency, so the rules are
/// testable without a device — matching signup_contract.dart and
/// incoming_alert_policy.dart.
library;

/// Prefix restaurant-service mints for rider codes
/// (internal/referralcore/codes.go).
const String riderReferralPrefix = 'MD';

/// A stored code is dropped after this long. A link followed months ago is
/// not evidence of who referred this rider, and the programme's own invite
/// expiry is enforced server-side regardless.
const Duration pendingReferralTtl = Duration(days: 30);

final RegExp _riderCodeShape = RegExp('^$riderReferralPrefix[A-Z0-9]{8}\$');

/// Normalises what a person may paste or type.
///
/// Only trims and upper-cases. It deliberately does not strip punctuation,
/// so an unrelated string cannot be squashed into a valid-looking code.
String normalizeReferralCode(String? value) =>
    (value ?? '').trim().toUpperCase();

/// Whether [value] is shaped like a **rider** referral code.
///
/// Shape only. Whether the code exists, is active, or belongs to a live
/// programme is the server's decision, and it is checked again at apply time.
///
/// Customer (`MG`) and restaurant (`MR`) codes are rejected here on purpose:
/// a rider signing up with a customer's code would otherwise be silently
/// attributed to the wrong programme.
bool isRiderReferralCode(String? value) =>
    _riderCodeShape.hasMatch(normalizeReferralCode(value));

/// A referral code captured before the rider had an account.
class PendingReferral {
  const PendingReferral({required this.code, required this.capturedAt});

  final String code;
  final DateTime capturedAt;

  bool isExpiredAt(DateTime now) => now.difference(capturedAt) >= pendingReferralTtl;
}

/// Whether a newly arrived [incoming] code should replace what is stored.
///
/// An existing pending code is kept: someone who followed two links should
/// stay with the first person who referred them, which is also the rule the
/// server enforces — one attribution per account, first one wins. An expired
/// stored code is replaced, because it can no longer be applied.
bool shouldStoreReferral({
  required String? incoming,
  required PendingReferral? stored,
  required DateTime now,
}) {
  if (!isRiderReferralCode(incoming)) return false;
  if (stored == null) return true;
  return stored.isExpiredAt(now);
}

/// Whether a stored code should be applied now that a session exists.
///
/// [isNewAccount] guards the brief's rule that referral codes are for new
/// accounts. Applying one for an established rider would be refused by the
/// server anyway, but asking is a wasted call and a confusing error.
bool shouldApplyAfterSignup({
  required PendingReferral? stored,
  required bool isNewAccount,
  required DateTime now,
}) {
  if (stored == null) return false;
  if (!isNewAccount) return false;
  if (stored.isExpiredAt(now)) return false;
  return isRiderReferralCode(stored.code);
}

/// Message shown when an already-signed-in rider opens a referral link.
const String referralForNewAccountsMessage =
    'Referral codes can only be used when creating a new account.';
