import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/domain/entities/app_models.dart';

void main() {
  test(
    'EarningsReport reads backend-computed wallet fields (Module 21)',
    () {
      final report = EarningsReport.fromJson({
        'today_earnings': 120,
        'wallet_balance': -2000.0,
        'pending_payout': 0,
        'settled_payout': 5400.0,
      });

      expect(report.walletBalance, -2000.0);
      expect(report.pendingPayout, 0);
      expect(report.settledPayout, 5400.0);
    },
  );

  test('EarningsReport defaults wallet fields to 0 when absent', () {
    final report = EarningsReport.fromJson({'today_earnings': 120});

    expect(report.walletBalance, 0);
    expect(report.pendingPayout, 0);
    expect(report.settledPayout, 0);
  });

  test('copyWith preserves wallet fields when not overridden', () {
    final report = EarningsReport.fromJson({
      'wallet_balance': 300.0,
      'pending_payout': 300.0,
      'settled_payout': 100.0,
    });

    final copy = report.copyWith(daily: 50);

    expect(copy.walletBalance, 300.0);
    expect(copy.pendingPayout, 300.0);
    expect(copy.settledPayout, 100.0);
    expect(copy.daily, 50);
  });
}
