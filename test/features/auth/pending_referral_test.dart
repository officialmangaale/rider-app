import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/auth/domain/pending_referral.dart';

/// A referral link is opened before the rider has an account, so the code has
/// to survive until a session exists. These pin when it is kept, replaced,
/// and applied.
void main() {
  final now = DateTime(2026, 9, 10);

  group('isRiderReferralCode', () {
    test('accepts a rider code, in any casing', () {
      for (final raw in ['MDF4A3M8TG', 'mdf4a3m8tg', '  MDF4A3M8TG  ']) {
        expect(isRiderReferralCode(raw), isTrue, reason: raw);
      }
    });

    // A rider signing up with a customer's code would otherwise be attributed
    // to the wrong programme.
    test('rejects codes from the other two programmes', () {
      expect(isRiderReferralCode('MG7KQP4XAB'), isFalse, reason: 'customer');
      expect(isRiderReferralCode('MR7KQP4XAB'), isFalse, reason: 'restaurant');
    });

    test('rejects the wrong shape', () {
      for (final bad in ['MDF4A3M8T', 'MDF4A3M8TGX', 'MDF4A3M8T!', '', '   ', null]) {
        expect(isRiderReferralCode(bad), isFalse, reason: '$bad');
      }
    });

    test('normalisation does not squash arbitrary text into a code', () {
      expect(normalizeReferralCode('  md-f4a3m8tg '), 'MD-F4A3M8TG');
      expect(isRiderReferralCode('md-f4a3m8tg'), isFalse);
    });
  });

  group('shouldStoreReferral', () {
    test('stores the first valid code', () {
      expect(
        shouldStoreReferral(incoming: 'MDF4A3M8TG', stored: null, now: now),
        isTrue,
      );
    });

    test('ignores anything that is not a rider code', () {
      expect(shouldStoreReferral(incoming: 'MG7KQP4XAB', stored: null, now: now), isFalse);
      expect(shouldStoreReferral(incoming: 'nonsense', stored: null, now: now), isFalse);
    });

    // The server keeps the first attribution and refuses the second, so the
    // app must not raise the rider's expectations by swapping codes.
    test('keeps the first referrer when a second link is opened', () {
      final first = PendingReferral(code: 'MDF4A3M8TG', capturedAt: now);
      expect(
        shouldStoreReferral(incoming: 'MDAAAAAAAA', stored: first, now: now),
        isFalse,
        reason: 'the first person to refer them should keep the attribution',
      );
    });

    test('replaces a stored code that can no longer be applied', () {
      final stale = PendingReferral(
        code: 'MDF4A3M8TG',
        capturedAt: now.subtract(pendingReferralTtl),
      );
      expect(
        shouldStoreReferral(incoming: 'MDAAAAAAAA', stored: stale, now: now),
        isTrue,
      );
    });
  });

  group('shouldApplyAfterSignup', () {
    final fresh = PendingReferral(code: 'MDF4A3M8TG', capturedAt: now);

    test('applies a fresh code for a brand-new rider', () {
      expect(
        shouldApplyAfterSignup(stored: fresh, isNewAccount: true, now: now),
        isTrue,
      );
    });

    // Referral codes are for new accounts. The server would refuse anyway;
    // not asking avoids a confusing error.
    test('does not apply for an existing rider', () {
      expect(
        shouldApplyAfterSignup(stored: fresh, isNewAccount: false, now: now),
        isFalse,
      );
    });

    test('does not apply when nothing was captured', () {
      expect(
        shouldApplyAfterSignup(stored: null, isNewAccount: true, now: now),
        isFalse,
      );
    });

    test('does not apply a code older than the retention window', () {
      final stale = PendingReferral(
        code: 'MDF4A3M8TG',
        capturedAt: now.subtract(pendingReferralTtl),
      );
      expect(
        shouldApplyAfterSignup(stored: stale, isNewAccount: true, now: now),
        isFalse,
      );
      // Just inside the window still applies.
      final justInside = PendingReferral(
        code: 'MDF4A3M8TG',
        capturedAt: now.subtract(pendingReferralTtl - const Duration(hours: 1)),
      );
      expect(
        shouldApplyAfterSignup(stored: justInside, isNewAccount: true, now: now),
        isTrue,
      );
    });

    test('never applies a code from another programme', () {
      final wrongProgramme = PendingReferral(code: 'MG7KQP4XAB', capturedAt: now);
      expect(
        shouldApplyAfterSignup(stored: wrongProgramme, isNewAccount: true, now: now),
        isFalse,
      );
    });
  });

  test('the signed-in message does not blame the rider', () {
    expect(referralForNewAccountsMessage.toLowerCase(), isNot(contains('invalid')));
    expect(referralForNewAccountsMessage.toLowerCase(), isNot(contains('error')));
    expect(referralForNewAccountsMessage, contains('new account'));
  });
}
