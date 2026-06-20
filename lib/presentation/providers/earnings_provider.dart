import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/services/rider_backend_api.dart';
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
    this.payoutSummary,
    this.reviews,
    this.totalEarnings = 0,
  });

  final EarningsReport? earnings;
  final PayoutSummary? payoutSummary;
  final ReviewInsights? reviews;
  final double totalEarnings;

  bool get hasAnyEarnings {
    final report = earnings;
    final payout = payoutSummary;
    return totalEarnings > 0 ||
        (report != null &&
            (report.daily > 0 ||
                report.weekly > 0 ||
                report.monthly > 0 ||
                report.deliveryFees > 0 ||
                report.incentives > 0 ||
                report.tips > 0 ||
                report.bonus > 0 ||
                report.trend.any((point) => point.amount > 0) ||
                report.payoutHistory.any((point) => point.amount > 0))) ||
        (payout != null &&
            (payout.walletBalance > 0 ||
                payout.pendingPayout > 0 ||
                payout.settledPayout > 0 ||
                payout.transactions.isNotEmpty));
  }

  EarningsState copyWith({
    EarningsReport? earnings,
    PayoutSummary? payoutSummary,
    ReviewInsights? reviews,
    double? totalEarnings,
  }) {
    return EarningsState(
      earnings: earnings ?? this.earnings,
      payoutSummary: payoutSummary ?? this.payoutSummary,
      reviews: reviews ?? this.reviews,
      totalEarnings: totalEarnings ?? this.totalEarnings,
    );
  }
}

class DeliveryHistoryState {
  const DeliveryHistoryState({this.records = const []});

  final List<DeliveryRecord> records;
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
    final prefs = ref.read(appPreferencesProvider);
    _debugEarnings(
      'GET /api/v1/earnings/summary start rawRole=${prefs.rawAuthRole ?? 'missing'} '
      'role=${prefs.authRole ?? 'missing'}',
    );

    final summaryEnvelope = await api.earnings.summary();
    final summaryData = summaryEnvelope.data;
    _debugEarnings(
      'GET /api/v1/earnings/summary status=${summaryEnvelope.statusCode ?? 'unknown'} '
      'shape=${_shape(summaryEnvelope.raw)} dataKeys=${summaryData.keys.join(',')}',
    );

    var earningsReport = EarningsReport.fromJson(summaryData);
    final payoutSummary = PayoutSummary.fromJson(summaryData);
    var totalEarnings = _asDouble(
      _firstPresent([
        summaryData['total_earnings'],
        summaryData['totalEarnings'],
        earningsReport.monthly,
      ]),
    );

    // Earnings ledger is optional context for trend and type breakdown.
    try {
      _debugEarnings('GET /api/v1/earnings/history start');
      final historyEnvelope = await api.earnings.history();
      final historyData = historyEnvelope.data;
      final items = _extractItems(historyData);
      final ledger = items
          .map(_asMap)
          .where((item) => item.isNotEmpty)
          .toList();
      final breakdown = _ledgerBreakdown(ledger);
      final ledgerTotal = breakdown.values.fold<double>(
        0,
        (sum, amount) => sum + amount,
      );
      if (ledgerTotal > 0 && totalEarnings <= 0) {
        totalEarnings = ledgerTotal;
      }
      earningsReport = earningsReport.copyWith(
        incentives: earningsReport.incentives > 0
            ? earningsReport.incentives
            : breakdown['incentive'],
        tips: earningsReport.tips > 0 ? earningsReport.tips : breakdown['tip'],
        bonus: earningsReport.bonus > 0
            ? earningsReport.bonus
            : breakdown['bonus'],
        deliveryFees: earningsReport.deliveryFees > 0
            ? earningsReport.deliveryFees
            : breakdown['delivery_fee'],
        trend: earningsReport.trend.isNotEmpty
            ? earningsReport.trend
            : _trendFromLedger(ledger),
        payoutHistory: earningsReport.payoutHistory.isNotEmpty
            ? earningsReport.payoutHistory
            : _pointsFromLedger(ledger),
      );
      _debugEarnings(
        'GET /api/v1/earnings/history status=${historyEnvelope.statusCode ?? 'unknown'} '
        'shape=${_shape(historyEnvelope.raw)} parsedCount=${ledger.length}',
      );
    } on ApiException catch (error) {
      _debugEarnings(
        'GET /api/v1/earnings/history optional failure '
        'status=${error.statusCode ?? 'unknown'} code=${error.errorCode ?? 'none'}',
      );
    } catch (error) {
      _debugEarnings(
        'GET /api/v1/earnings/history optional parse failure $error',
      );
    }

    _debugEarnings(
      'earnings parsed total=$totalEarnings empty=${totalEarnings <= 0 && !earningsReport.trend.any((point) => point.amount > 0)}',
    );
    return EarningsState(
      earnings: earningsReport,
      payoutSummary: payoutSummary,
      totalEarnings: totalEarnings,
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
    _debugEarnings('retry action refresh earnings');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

final deliveryHistoryControllerProvider =
    AsyncNotifierProvider<DeliveryHistoryController, DeliveryHistoryState>(
      DeliveryHistoryController.new,
    );

class DeliveryHistoryController extends AsyncNotifier<DeliveryHistoryState> {
  @override
  Future<DeliveryHistoryState> build() => _fetch();

  Future<DeliveryHistoryState> _fetch() async {
    final api = ref.read(riderBackendApiProvider);
    final prefs = ref.read(appPreferencesProvider);
    if ((prefs.accessToken ?? '').isEmpty) {
      _debugHistory('history skipped authTokenPresent=no');
      throw const ApiException(
        message: 'Please sign in again to view delivery history.',
        statusCode: 401,
        errorCode: 'AUTH_REQUIRED',
      );
    }

    _debugHistory(
      'history fetch start rawRole=${prefs.rawAuthRole ?? 'missing'} '
      'role=${prefs.authRole ?? 'missing'}',
    );

    final records = <DeliveryRecord>[];
    final hardFailures = <ApiException>[];

    for (final status in const ['delivered', 'cancelled']) {
      try {
        records.addAll(await _loadRiderOrders(api, status));
      } on ApiException catch (error) {
        if (error.statusCode != 404) {
          hardFailures.add(error);
        }
        _debugHistory(
          'GET /api/v1/riders/orders?status=$status failure '
          'status=${error.statusCode ?? 'unknown'} code=${error.errorCode ?? 'none'}',
        );
      }
    }

    try {
      records.addAll(await _loadLegacyOrderHistory(api));
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        hardFailures.add(error);
      }
      _debugHistory(
        'GET /api/v1/orders/history failure '
        'status=${error.statusCode ?? 'unknown'} code=${error.errorCode ?? 'none'}',
      );
    }

    final unique = _dedupeHistory(records);
    if (unique.isEmpty && hardFailures.isNotEmpty) {
      _debugHistory('history decision=error failures=${hardFailures.length}');
      throw hardFailures.first;
    }

    _debugHistory(
      'history decision=${unique.isEmpty ? 'empty' : 'data'} parsedCount=${unique.length}',
    );
    return DeliveryHistoryState(records: unique);
  }

  Future<void> refresh() async {
    _debugHistory('retry action refresh history');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<List<DeliveryRecord>> _loadRiderOrders(
    RiderBackendApi api,
    String status,
  ) async {
    final endpoint = '/api/v1/riders/orders?status=$status';
    _debugHistory('GET $endpoint start');
    final response = await api.delivery.riderOrders(
      queryParameters: {'status': status},
    );
    final items = _extractItems(response.data);
    final records = _mapRecords(items);
    _debugHistory(
      'GET $endpoint status=${response.statusCode ?? 'unknown'} '
      'shape=${_shape(response.raw)} parsedCount=${records.length}',
    );
    return records;
  }

  Future<List<DeliveryRecord>> _loadLegacyOrderHistory(
    RiderBackendApi api,
  ) async {
    const endpoint = '/api/v1/orders/history';
    _debugHistory('GET $endpoint start');
    final response = await api.orders.orderHistory();
    final items = _extractItems(response.data);
    final records = _mapRecords(items);
    _debugHistory(
      'GET $endpoint status=${response.statusCode ?? 'unknown'} '
      'shape=${_shape(response.raw)} parsedCount=${records.length}',
    );
    return records;
  }

  List<DeliveryRecord> _mapRecords(List<dynamic> items) {
    final mapped = <DeliveryRecord>[];
    for (final item in items) {
      final map = _asMap(item);
      if (map.isEmpty) {
        continue;
      }
      mapped.add(DeliveryRecord.fromJson(map));
    }
    return mapped;
  }

  List<DeliveryRecord> _dedupeHistory(List<DeliveryRecord> records) {
    final byId = <String, DeliveryRecord>{};
    for (final record in records) {
      byId[record.id] = record;
    }
    return byId.values.toList(growable: false)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }
}

List<dynamic> _extractItems(Map<String, dynamic> data) {
  for (final key in const ['items', 'orders', 'data', 'results']) {
    final value = data[key];
    if (value is List) {
      return value;
    }
    if (value is Map) {
      final nested = _extractItems(_asMap(value));
      if (nested.isNotEmpty) {
        return nested;
      }
    }
  }
  return const <dynamic>[];
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

Object? _firstPresent(List<Object?> values) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return value;
  }
  return null;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

Map<String, double> _ledgerBreakdown(List<Map<String, dynamic>> ledger) {
  final values = <String, double>{
    'delivery_fee': 0,
    'tip': 0,
    'incentive': 0,
    'bonus': 0,
    'penalty': 0,
  };
  for (final row in ledger) {
    final type = '${row['type'] ?? ''}'.trim().toLowerCase();
    final amount = _asDouble(row['amount']);
    values[type] = (values[type] ?? 0) + amount;
  }
  return values;
}

List<EarningsPoint> _trendFromLedger(List<Map<String, dynamic>> ledger) {
  final buckets = SplayTreeMap<DateTime, double>();
  for (final row in ledger) {
    final createdAt = DateTime.tryParse('${row['created_at'] ?? ''}');
    if (createdAt == null) {
      continue;
    }
    final key = DateTime(createdAt.year, createdAt.month, createdAt.day);
    buckets[key] = (buckets[key] ?? 0) + _asDouble(row['amount']);
  }

  return buckets.entries
      .toList()
      .reversed
      .take(7)
      .toList()
      .reversed
      .map(
        (entry) => EarningsPoint(
          label: _weekdayLabel(entry.key.weekday),
          amount: entry.value,
        ),
      )
      .toList(growable: false);
}

List<EarningsPoint> _pointsFromLedger(List<Map<String, dynamic>> ledger) {
  return ledger
      .take(5)
      .map(
        (row) => EarningsPoint(
          label: '${row['description'] ?? row['type'] ?? 'Earning'}',
          amount: _asDouble(row['amount']),
        ),
      )
      .toList(growable: false);
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    _ => 'Sun',
  };
}

String _shape(Map<String, dynamic> payload) {
  final data = payload['data'];
  final dataShape = data is Map
      ? 'dataKeys=${data.keys.join(',')}'
      : data is List
      ? 'dataList=${data.length}'
      : 'data=${data.runtimeType}';
  return 'keys=${payload.keys.join(',')} $dataShape';
}

void _debugEarnings(String message) {
  assert(() {
    debugPrint('[RiderEarnings] $message');
    return true;
  }());
}

void _debugHistory(String message) {
  assert(() {
    debugPrint('[RiderHistory] $message');
    return true;
  }());
}
