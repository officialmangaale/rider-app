import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Earnings state — earnings report and history.
// Backend has: GET /api/v1/earnings/summary, GET /api/v1/earnings/history.
// No separate ratings, payouts, wallet, or incentive endpoints.
// ---------------------------------------------------------------------------

class EarningsState {
  const EarningsState({
    this.earnings,
    this.history = const [],
    this.payoutSummary,
    this.reviews,
  });

  final EarningsReport? earnings;
  final List<DeliveryRecord> history;
  final PayoutSummary? payoutSummary;
  final ReviewInsights? reviews;

  EarningsState copyWith({
    EarningsReport? earnings,
    List<DeliveryRecord>? history,
    PayoutSummary? payoutSummary,
    ReviewInsights? reviews,
  }) {
    return EarningsState(
      earnings: earnings ?? this.earnings,
      history: history ?? this.history,
      payoutSummary: payoutSummary ?? this.payoutSummary,
      reviews: reviews ?? this.reviews,
    );
  }
}

final earningsControllerProvider =
    AsyncNotifierProvider<EarningsController, EarningsState>(
  EarningsController.new,
);

class EarningsController extends AsyncNotifier<EarningsState> {
  @override
  Future<EarningsState> build() => _fetch();

  Future<EarningsState> _fetch() async {
    final api = ref.read(riderBackendApiProvider);
    final summaryEnvelope = await api.earnings.summary();
    final summaryData = summaryEnvelope.data;

    final earningsReport = EarningsReport.fromJson(summaryData);
    final payoutSummary = PayoutSummary.fromJson(summaryData);

    // History loaded separately for pagination readiness.
    List<DeliveryRecord> historyList = [];
    try {
      final historyEnvelope = await api.earnings.history();
      final historyData = historyEnvelope.data;
      // Backend returns paginated: {items: [...], pagination: {...}}
      final items = historyData['items'] as List<dynamic>? ?? const [];
      historyList = items
          .map(
            (item) => DeliveryRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      // History load failure shouldn't block earnings display.
    }

    return EarningsState(
      earnings: earningsReport,
      history: historyList,
      payoutSummary: payoutSummary,
    );
  }

  /// Payout request — not available on backend yet, but kept as stub.
  Future<void> requestPayout({required double amount}) async {
    // Backend does not have a payout endpoint yet.
    // When it does, uncomment below:
    // final api = ref.read(riderBackendApiProvider);
    // await api.earnings.requestPayout(amount: amount);
    // await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}
