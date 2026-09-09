import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/domain/entities/referral_models.dart';

void main() {
  group('RiderReferralDashboard.fromJson', () {
    test('reads the full backend payload', () {
      final dashboard = RiderReferralDashboard.fromJson(const {
        'program_type': 'rider_referral',
        'enabled': true,
        'code': 'MDT4KQ9WXB',
        'share_link': 'https://mangaale.com/r/MDT4KQ9WXB',
        'share_message': 'Ride with Mangaale — use MDT4KQ9WXB',
        'reward_summary': '₹300 bonus',
        'reward_millis': 300000,
        'pending_count': 2,
        'qualified_count': 1,
        'rewarded_count': 3,
        'total_earned_millis': 900000,
        'available_reward_millis': 300000,
        'referrals': [
          {
            'referral_id': 7,
            'status': 'rewarded',
            'masked_name': 'Harpreet S.',
            'reward_millis': 300000,
          },
        ],
      });

      expect(dashboard.enabled, isTrue);
      expect(dashboard.code, 'MDT4KQ9WXB');
      expect(dashboard.rewardSummary, '₹300 bonus');
      expect(dashboard.totalEarnedMillis, 900000);
      expect(dashboard.referrals.single.maskedName, 'Harpreet S.');
    });

    // A referral screen must never crash a working app. Every field is
    // optional as far as the parser is concerned.
    test('an empty or partial payload parses to safe defaults', () {
      final empty = RiderReferralDashboard.fromJson(const {});
      expect(empty.enabled, isFalse);
      expect(empty.code, '');
      expect(empty.referrals, isEmpty);
      expect(empty.totalEarnedMillis, 0);

      final partial = RiderReferralDashboard.fromJson(const {
        'code': 'MDABC12345',
        'referrals': 'not-a-list',
      });
      expect(partial.code, 'MDABC12345');
      expect(partial.referrals, isEmpty);
    });

    // Postgres BIGINT can arrive as a JSON string through some proxies.
    test('numbers arriving as strings are still read', () {
      final dashboard = RiderReferralDashboard.fromJson(const {
        'total_earned_millis': '600000',
        'rewarded_count': '2',
      });
      expect(dashboard.totalEarnedMillis, 600000);
      expect(dashboard.rewardedCount, 2);
    });
  });

  group('RiderReferralEntry.label', () {
    test('translates every backend status into rider-facing wording', () {
      const cases = <String, String>{
        'pending': 'Completing their first deliveries',
        'fraud_review': 'Being reviewed',
        'qualified': 'Bonus on its way',
        'reward_pending': 'Bonus on its way',
        'rewarded': 'Bonus paid',
        'rejected': 'Not eligible',
        'expired': 'Expired',
        'reversed': 'Reversed',
      };
      cases.forEach((status, expected) {
        expect(_entry(status).label, expected, reason: 'status $status');
      });
    });

    // Showing a rider the word "fraud" accuses them of something; in practice
    // the state usually means a shared device needs a human look. No raw
    // lifecycle vocabulary may reach the screen.
    test('no label leaks raw lifecycle vocabulary', () {
      const statuses = [
        'pending',
        'fraud_review',
        'qualified',
        'reward_pending',
        'rewarded',
        'rejected',
        'expired',
        'reversed',
        'some_status_added_later',
      ];
      for (final status in statuses) {
        final label = _entry(status).label;
        expect(label, isNot(contains('_')), reason: status);
        expect(label.toLowerCase(), isNot(contains('fraud')), reason: status);
      }
    });

    // An unknown status must degrade to something harmless rather than
    // rendering an internal token.
    test('an unrecognised status falls back to a neutral label', () {
      expect(_entry('brand_new_state').label, 'In progress');
      expect(_entry('').label, 'In progress');
    });

    test('only a rewarded referral counts as paid', () {
      expect(_entry('rewarded').isPaid, isTrue);
      for (final status in ['pending', 'qualified', 'reward_pending',
        'reversed', 'expired']) {
        expect(_entry(status).isPaid, isFalse, reason: status);
      }
    });
  });

  group('formatMillis', () {
    test('renders whole rupees without decimals', () {
      expect(formatMillis(300000), '₹300');
      expect(formatMillis(0), '₹0');
      expect(formatMillis(600000), '₹600');
    });

    // A part-rupee amount must not be silently rounded into a number the
    // rider's earnings screen would disagree with.
    test('keeps decimals when the amount is not whole rupees', () {
      expect(formatMillis(300500), '₹300.50');
      expect(formatMillis(1), '₹0.00');
    });
  });
}

RiderReferralEntry _entry(String status) => RiderReferralEntry(
  referralId: 1,
  status: status,
  maskedName: 'A. R.',
  rewardMillis: 0,
);
