import '../../domain/entities/app_models.dart';
import '../../domain/repositories/rider_repository.dart';
import '../datasources/asset_mock_data_source.dart';

class MockRiderRepository implements RiderRepository {
  const MockRiderRepository(this._dataSource);

  final AssetMockDataSource _dataSource;

  @override
  Future<RiderHubState> bootstrap() async {
    final results = await Future.wait<dynamic>([
      _dataSource.loadObject('assets/mock/profile.json'),
      _dataSource.loadList('assets/mock/orders.json'),
      _dataSource.loadObject('assets/mock/active_order.json'),
      _dataSource.loadObject('assets/mock/earnings.json'),
      _dataSource.loadList('assets/mock/notifications.json'),
      _dataSource.loadList('assets/mock/history.json'),
      _dataSource.loadObject('assets/mock/payouts.json'),
      _dataSource.loadObject('assets/mock/reviews.json'),
      _dataSource.loadList('assets/mock/support.json'),
    ]);

    final profile = RiderProfile.fromJson(results[0] as Map<String, dynamic>);
    final incomingOrders = (results[1] as List<dynamic>)
        .map((item) => DeliveryOrder.fromJson(item as Map<String, dynamic>))
        .toList();
    final activeOrderPayload = results[2] as Map<String, dynamic>;
    final activeOrder = activeOrderPayload.isEmpty
        ? null
        : DeliveryOrder.fromJson(activeOrderPayload);
    final earnings = EarningsReport.fromJson(
      results[3] as Map<String, dynamic>,
    );
    final notifications = (results[4] as List<dynamic>)
        .map(
          (item) => AppNotificationItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final history = (results[5] as List<dynamic>)
        .map((item) => DeliveryRecord.fromJson(item as Map<String, dynamic>))
        .toList();
    final payouts = PayoutSummary.fromJson(results[6] as Map<String, dynamic>);
    final reviews = ReviewInsights.fromJson(results[7] as Map<String, dynamic>);
    final supportFaqs = (results[8] as List<dynamic>)
        .map((item) => SupportFaq.fromJson(item as Map<String, dynamic>))
        .toList();

    return RiderHubState(
      profile: profile,
      earnings: earnings,
      notifications: notifications,
      history: history,
      payoutSummary: payouts,
      reviews: reviews,
      supportFaqs: supportFaqs,
      shiftSummary: ShiftSummary.fromJson({
        'status': 'online',
        'shiftStart': '2026-03-15T09:00:00.000',
        'shiftEnd': '2026-03-15T19:00:00.000',
        'breakMinutes': 25,
        'preferredWindow': 'Lunch + dinner premium band',
        'activeHours': 7.5,
        'statusMessage': 'Live on priority dispatch lane',
      }),
      incomingOrders: incomingOrders,
      activeOrder: activeOrder,
      queuedOrders: const [],
    );
  }

  @override
  Future<void> loginWithPassword({
    required String login,
    required String password,
  }) async {}

  @override
  Future<AuthOtpChallenge> sendLoginOtp({required String login}) async {
    return const AuthOtpChallenge(expiresInSeconds: 300, channel: 'SMS');
  }

  @override
  Future<void> verifyLoginOtp({
    required String login,
    required String otp,
  }) async {}

  @override
  Future<AuthOtpChallenge> requestPasswordReset({required String login}) async {
    return const AuthOtpChallenge(expiresInSeconds: 300, channel: 'SMS');
  }

  @override
  Future<void> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> acceptOrder(String assignmentId) async {}

  @override
  Future<void> rejectOrder(String assignmentId, {String? reason}) async {}

  @override
  Future<void> setAvailabilityStatus(AvailabilityStatus status) async {}

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<void> advanceActiveOrder(DeliveryOrder order, {String? otp}) async {}
}
