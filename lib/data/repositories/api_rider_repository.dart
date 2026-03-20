import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/services/app_preferences.dart';
import '../../domain/entities/app_models.dart';
import '../../domain/repositories/rider_repository.dart';
import '../datasources/asset_mock_data_source.dart';
import '../services/rider_backend_api.dart';

class ApiRiderRepository implements RiderRepository {
  ApiRiderRepository({
    required RiderBackendApi api,
    required AppPreferences preferences,
    required AssetMockDataSource assetMockDataSource,
  }) : _api = api,
       _preferences = preferences,
       _assetMockDataSource = assetMockDataSource;

  final RiderBackendApi _api;
  final AppPreferences _preferences;
  final AssetMockDataSource _assetMockDataSource;

  @override
  Future<RiderHubState> bootstrap() async {
    final now = DateTime.now();
    final futures = await Future.wait<Object?>([
      _api.riderProfile.me(),
      _api.riderProfile.status(),
      _safeList(() => _api.availability.todayShift()),
      _safeList(() => _api.orders.orderRequests()),
      _activeOrderOrNull(),
      _safeList(() => _api.orders.assignedOrders()),
      _safeList(() => _api.orders.orderHistory()),
      _safeList(() => _api.notifications.notifications()),
      _api.ratings.summary(),
      _safeList(() => _api.ratings.reviews()),
      _api.ratings.performanceScore(),
      _api.earnings.today(),
      _api.earnings.weekly(),
      _api.earnings.monthly(),
      _api.earnings.summary(),
      _safeList(() => _api.earnings.incentives()),
      _safeList(() => _api.earnings.bonusHistory()),
      _safeList(() => _api.earnings.walletTransactions()),
      _safeList(() => _api.earnings.payouts()),
      _safeObject(() => _api.earnings.bankAccount()),
      _loadSupportFaqs(),
    ]);

    final profileEnvelope = futures[0] as dynamic;
    final statusEnvelope = futures[1] as dynamic;
    final todayShift = futures[2] as List<dynamic>;
    final orderRequests = futures[3] as List<dynamic>;
    final activeOrderPayload = futures[4] as Map<String, dynamic>?;
    final assignedOrdersPayload = futures[5] as List<dynamic>;
    final historyPayload = futures[6] as List<dynamic>;
    final notificationsPayload = futures[7] as List<dynamic>;
    final ratingSummaryEnvelope = futures[8] as dynamic;
    final reviewsPayload = futures[9] as List<dynamic>;
    final performanceEnvelope = futures[10] as dynamic;
    final todayEarningsEnvelope = futures[11] as dynamic;
    final weeklyEarningsEnvelope = futures[12] as dynamic;
    final monthlyEarningsEnvelope = futures[13] as dynamic;
    final earningsSummaryEnvelope = futures[14] as dynamic;
    final incentivesPayload = futures[15] as List<dynamic>;
    final bonusPayload = futures[16] as List<dynamic>;
    final walletTransactionsPayload = futures[17] as List<dynamic>;
    final payoutsPayload = futures[18] as List<dynamic>;
    final bankAccountPayload = futures[19] as Map<String, dynamic>;
    final supportFaqs = futures[20] as List<SupportFaq>;

    final profileData = _asMap(profileEnvelope.data);
    final statusData = _asMap(statusEnvelope.data);
    final user = _asMap(profileData['user']);
    final rider = _asMap(profileData['rider']);
    final vehicle = _asMap(profileData['vehicle']);
    final documents = _asList(profileData['documents'])
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .toList();

    final incomingOrders = orderRequests
        .map((entry) => _mapDeliveryOrder(entry, now: now, isIncoming: true))
        .toList()
      ..sort((a, b) => a.countdownSeconds.compareTo(b.countdownSeconds));

    DeliveryOrder? activeOrder = activeOrderPayload == null
        ? null
        : _mapDeliveryOrder(activeOrderPayload, now: now);

    var queuedOrders = assignedOrdersPayload
        .map((entry) => _mapDeliveryOrder(entry, now: now, isMultiOrder: true))
        .where((entry) => entry.id != activeOrder?.id)
        .toList();

    if (activeOrder == null && queuedOrders.isNotEmpty) {
      activeOrder = queuedOrders.first.copyWith(isMultiOrder: false);
      queuedOrders = queuedOrders.sublist(1);
    }
    if (queuedOrders.isNotEmpty) {
      queuedOrders = queuedOrders
          .map((entry) => entry.copyWith(isMultiOrder: true))
          .toList();
    }

    final history = historyPayload.map(_mapDeliveryRecord).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final notifications = notificationsPayload.map(_mapNotification).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final todayEarningsData = _asMap(todayEarningsEnvelope.data);
    final weeklyEarningsData = _asMap(weeklyEarningsEnvelope.data);
    final monthlyEarningsData = _asMap(monthlyEarningsEnvelope.data);
    final earningsSummaryData = _asMap(earningsSummaryEnvelope.data);
    final walletData = _asMap(earningsSummaryData['wallet']);
    final monthlyRecords = _extractRecords(monthlyEarningsData);
    final payoutTransactions = walletTransactionsPayload
        .map(_mapWalletTransaction)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final payoutRequests = payoutsPayload.map(_asMap).toList();

    final earnings = EarningsReport(
      daily: _asDouble(todayEarningsData['total']),
      weekly: _asDouble(weeklyEarningsData['total']),
      monthly: _asDouble(monthlyEarningsData['total']),
      incentives: _sumByKeys(
        incentivesPayload.map(_asMap),
        const ['incentive_amount', 'amount', 'net_earning'],
      ),
      tips: _sumByKeys(monthlyRecords, const ['tip_amount']),
      bonus: _sumByKeys(
        bonusPayload.map(_asMap),
        const ['bonus_amount', 'surge_bonus', 'incentive_amount', 'amount'],
      ),
      trend: _buildTrendPoints(monthlyRecords),
      payoutHistory: _buildPayoutHistoryPoints(payoutRequests, payoutTransactions),
    );

    final payoutSummary = PayoutSummary(
      walletBalance: _asDouble(walletData['balance']),
      pendingPayout:
          _sumPayoutAmounts(
            payoutRequests,
            const ['pending', 'approved', 'processing'],
          ) +
          _asDouble(walletData['hold_balance']),
      settledPayout: _sumPayoutAmounts(
        payoutRequests,
        const ['paid', 'settled', 'completed'],
      ),
      bankAccountMasked: _maskedBankAccount(bankAccountPayload),
      transactions: payoutTransactions,
    );

    final ratingsSummaryData = _asMap(ratingSummaryEnvelope.data);
    final performanceData = _asMap(performanceEnvelope.data);
    final averageRating = _asDouble(
      ratingsSummaryData['average_rating'] ?? rider['avg_rating'],
    );
    final reviews = reviewsPayload.map(_mapReview).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final reviewInsights = ReviewInsights(
      averageRating: averageRating,
      performanceScore: _asDouble(performanceData['score']),
      compliments: _buildCompliments(
        performanceData: performanceData,
        averageRating: averageRating,
      ),
      reviews: reviews,
    );

    final allAddresses = <String>[
      ...incomingOrders.map((entry) => entry.dropAddress),
      if (activeOrder != null) activeOrder.dropAddress,
      ...history.take(5).map((entry) => entry.dropAddress),
    ];
    final activeStatus = availabilityStatusFromJson(
      _stringOrFallback(
        statusData['availability_status'],
        fallback: _stringOrFallback(rider['availability_status']),
      ),
    );

    final shiftSummary = _buildShiftSummary(
      now: now,
      status: activeStatus,
      statusData: statusData,
      todayShift: todayShift.map(_asMap).toList(),
      activeHoursHint: _asDouble(rider['active_hours_today']),
    );

    final displayName = _displayName(user);
    final profile = RiderProfile(
      name: displayName,
      phone:
          _firstNonEmptyString([
            _stringOrNull(user['phone']),
            activeOrder?.customerPhone,
          ]) ??
          'Phone pending',
      city:
          _firstNonEmptyString([
            _stringOrNull(user['city']),
            _stringOrNull(rider['city']),
            _inferCity(allAddresses),
          ]) ??
          'Dispatch zone',
      vehicleType: _vehicleTypeLabel(
        _firstNonEmptyString([
              _stringOrNull(vehicle['vehicle_type']),
              _stringOrNull(rider['vehicle_type']),
            ]) ??
            'BIKE',
      ),
      vehicleNumber:
          _firstNonEmptyString([
            _stringOrNull(vehicle['registration_no']),
            _stringOrNull(rider['vehicle_number']),
          ]) ??
          'Vehicle pending',
      licenseStatus: _licenseStatus(
        documents: documents,
        rider: rider,
        statusData: statusData,
      ),
      shiftPreference: _preferredWindowLabel(shiftSummary.shiftStart),
      rating: averageRating,
      completedDeliveries: history.length,
      activeDeliveries: activeOrder == null ? 0 : 1,
      todayEarnings: _asDouble(todayEarningsData['total']),
      avatarInitials: _initialsForName(displayName),
    );

    return RiderHubState(
      profile: profile,
      earnings: earnings,
      notifications: notifications,
      history: history,
      payoutSummary: payoutSummary,
      reviews: reviewInsights,
      supportFaqs: supportFaqs,
      shiftSummary: shiftSummary,
      incomingOrders: incomingOrders,
      activeOrder: activeOrder,
      queuedOrders: queuedOrders,
    );
  }

  @override
  Future<void> loginWithPassword({
    required String login,
    required String password,
  }) async {
    final response = await _api.auth.login(
      login: login,
      password: password,
      deviceId: await _preferences.getDeviceId(),
      deviceName: _deviceName,
    );
    await _storeTokens(response.data);
  }

  @override
  Future<AuthOtpChallenge> sendLoginOtp({required String login}) async {
    final response = await _api.auth.sendRiderOtp(login: login);
    return _mapOtpChallenge(response.data);
  }

  @override
  Future<void> verifyLoginOtp({
    required String login,
    required String otp,
  }) async {
    final response = await _api.auth.verifyRiderOtp(
      login: login,
      otp: otp,
      deviceId: await _preferences.getDeviceId(),
      deviceName: _deviceName,
    );
    await _storeTokens(response.data);
  }

  @override
  Future<AuthOtpChallenge> requestPasswordReset({required String login}) async {
    final response = await _api.auth.forgotPassword(login: login);
    return _mapOtpChallenge(response.data);
  }

  @override
  Future<void> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  }) {
    return _api.auth.resetPassword(
      login: login,
      otp: otp,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = _preferences.refreshToken;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _api.auth.logout(refreshToken: refreshToken);
      }
    } on ApiException {
      // Clearing local auth state is more important than surfacing logout noise.
    } finally {
      await _preferences.clearTokens();
    }
  }

  @override
  Future<void> acceptOrder(String assignmentId) {
    return _api.orders.acceptOrderRequest(assignmentId);
  }

  @override
  Future<void> rejectOrder(String assignmentId, {String? reason}) {
    return _api.orders.rejectOrderRequest(
      assignmentId,
      reason: reason ?? 'Not available right now',
    );
  }

  @override
  Future<void> setAvailabilityStatus(AvailabilityStatus status) async {
    switch (status) {
      case AvailabilityStatus.online:
      case AvailabilityStatus.busy:
        await _endBreakIfActive();
        await _ensureShiftAndGoOnline();
        return;
      case AvailabilityStatus.onBreak:
        await _api.availability.startBreak(reason: 'Break requested from app');
        return;
      case AvailabilityStatus.offline:
        await _endBreakIfActive();
        await _api.availability.goOffline();
        return;
    }
  }

  @override
  Future<void> markNotificationRead(String id) {
    return _api.notifications.markRead(id);
  }

  @override
  Future<void> markAllNotificationsRead() {
    return _api.notifications.markAllRead();
  }

  @override
  Future<void> advanceActiveOrder(DeliveryOrder order, {String? otp}) async {
    switch (order.status) {
      case DeliveryStage.assigned:
        if (order.assignmentId == null || order.assignmentId!.isEmpty) {
          throw const ApiException(
            message: 'Missing assignment id for this order request.',
            errorCode: 'ASSIGNMENT_REQUIRED',
          );
        }
        await acceptOrder(order.assignmentId!);
        return;
      case DeliveryStage.accepted:
        await _api.orders.arrivedAtRestaurant(order.id);
        return;
      case DeliveryStage.reachedRestaurant:
        if (order.pickupOtpRequired) {
          final providedOtp = otp?.trim() ?? '';
          if (providedOtp.isEmpty) {
            throw const ApiException(
              message: 'Pickup OTP is required before pickup.',
              errorCode: 'PICKUP_OTP_REQUIRED',
            );
          }
          await _api.otpVerification.verifyPickupOtp(
            orderId: order.id,
            otp: providedOtp,
          );
        }
        await _api.orders.pickedUp(order.id);
        return;
      case DeliveryStage.pickedUp:
        await _api.orders.startDelivery(order.id);
        return;
      case DeliveryStage.onTheWay:
        await _api.orders.arrivedAtCustomer(order.id);
        return;
      case DeliveryStage.reachedCustomer:
        if (order.deliveryOtpRequired) {
          final providedOtp = otp?.trim() ?? '';
          if (providedOtp.isEmpty) {
            throw const ApiException(
              message: 'Delivery OTP is required before completion.',
              errorCode: 'DELIVERY_OTP_REQUIRED',
            );
          }
          await _api.otpVerification.verifyDeliveryOtp(
            orderId: order.id,
            otp: providedOtp,
          );
        }
        await _api.orders.deliver(order.id);
        return;
      case DeliveryStage.delivered:
        return;
    }
  }

  Future<void> _storeTokens(Map<String, dynamic> payload) async {
    final tokens = _asMap(payload['tokens']);
    final accessToken = _firstNonEmptyString([
      _stringOrNull(tokens['access_token']),
      _stringOrNull(payload['access_token']),
    ]);
    final refreshToken = _firstNonEmptyString([
      _stringOrNull(tokens['refresh_token']),
      _stringOrNull(payload['refresh_token']),
    ]);

    if (accessToken == null || refreshToken == null) {
      throw const ApiException(
        message: 'Authentication tokens are missing from the response.',
        errorCode: 'TOKEN_MISSING',
      );
    }

    await _preferences.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> _endBreakIfActive() async {
    try {
      await _api.availability.endBreak();
    } on ApiException catch (error) {
      if (error.errorCode != 'NO_ACTIVE_BREAK' && error.statusCode != 404) {
        rethrow;
      }
    }
  }

  Future<void> _ensureShiftAndGoOnline() async {
    try {
      await _api.availability.goOnline();
    } on ApiException catch (error) {
      if (error.errorCode == 'SHIFT_REQUIRED' ||
          error.errorCode == 'NO_ACTIVE_SHIFT') {
        await _api.availability.startShift();
        await _api.availability.goOnline();
        return;
      }
      if (error.errorCode == 'SHIFT_ALREADY_ACTIVE') {
        await _api.availability.goOnline();
        return;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> _safeList(Future<dynamic> Function() request) async {
    try {
      final response = await request();
      return _asList(response.data);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return const <dynamic>[];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _safeObject(
    Future<dynamic> Function() request,
  ) async {
    try {
      final response = await request();
      return _asMap(response.data);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return const <String, dynamic>{};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _activeOrderOrNull() async {
    try {
      final response = await _api.orders.activeOrder();
      return _asMap(response.data);
    } on ApiException catch (error) {
      if (error.errorCode == 'ACTIVE_ORDER_NOT_FOUND' ||
          error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<SupportFaq>> _loadSupportFaqs() async {
    try {
      final payload = await _assetMockDataSource.loadList('assets/mock/support.json');
      return payload
          .map((entry) => SupportFaq.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const <SupportFaq>[];
    }
  }

  AuthOtpChallenge _mapOtpChallenge(Map<String, dynamic> data) {
    return AuthOtpChallenge(
      expiresInSeconds: _asInt(data['expires_in_seconds']) ?? 300,
      channel:
          _firstNonEmptyString([
            _stringOrNull(data['channel']),
            _stringOrNull(data['delivery_channel']),
          ]) ??
          'SMS',
    );
  }

  DeliveryOrder _mapDeliveryOrder(
    dynamic rawEntry, {
    required DateTime now,
    bool isIncoming = false,
    bool isMultiOrder = false,
  }) {
    final entry = _asMap(rawEntry);
    final assignment = _asMap(entry['assignment']);
    final order = entry['order'] is Map<String, dynamic>
        ? _asMap(entry['order'])
        : entry;
    final items = _asList(entry['items'] ?? order['items']).map(_asMap).toList();

    final payout =
        _asDouble(order['base_payout']) +
        _asDouble(order['distance_payout']) +
        _asDouble(order['waiting_charges']) +
        _asDouble(order['surge_bonus']);
    final tip = _asDouble(order['tip_amount']);
    final decisionDeadline = _readDateTime(
      assignment['decision_deadline_at'] ?? order['decision_deadline_at'],
    );
    final countdownSeconds = decisionDeadline == null
        ? _asInt(order['countdown_seconds']) ?? 0
        : decisionDeadline.difference(now).inSeconds.clamp(0, 1 << 31);
    final itemsCount = items.isNotEmpty
        ? items.fold<int>(
            0,
            (sum, item) => sum + (_asInt(item['quantity']) ?? 1),
          )
        : _asInt(order['items_count']) ??
            _asInt(order['item_count']) ??
            _asInt(order['total_items']) ??
            0;

    return DeliveryOrder(
      id:
          _firstNonEmptyString([
            _stringOrNull(order['id']),
            _stringOrNull(entry['id']),
          ]) ??
          'order-${now.microsecondsSinceEpoch}',
      assignmentId: _firstNonEmptyString([
        _stringOrNull(assignment['id']),
        _stringOrNull(order['assignment_id']),
        _stringOrNull(entry['assignment_id']),
      ]),
      restaurantName:
          _firstNonEmptyString([
            _stringOrNull(order['restaurant_name']),
            _stringOrNull(_asMap(order['restaurant'])['name']),
            _stringOrNull(entry['restaurant_name']),
            _stringOrNull(assignment['restaurant_name']),
          ]) ??
          _restaurantLabel(order),
      customerName:
          _firstNonEmptyString([
            _stringOrNull(order['customer_name']),
            _stringOrNull(entry['customer_name']),
          ]) ??
          'Customer',
      pickupAddress:
          _firstNonEmptyString([
            _stringOrNull(order['pickup_address']),
            _stringOrNull(order['restaurant_address']),
            _stringOrNull(_asMap(order['restaurant'])['address']),
            _stringOrNull(entry['pickup_address']),
          ]) ??
          'Pickup location pending',
      dropAddress:
          _firstNonEmptyString([
            _stringOrNull(order['delivery_address']),
            _stringOrNull(order['drop_address']),
            _stringOrNull(entry['delivery_address']),
          ]) ??
          'Delivery address pending',
      restaurantPhone:
          _firstNonEmptyString([
            _stringOrNull(order['restaurant_phone']),
            _stringOrNull(_asMap(order['restaurant'])['phone']),
            _stringOrNull(entry['restaurant_phone']),
          ]) ??
          '',
      customerPhone:
          _firstNonEmptyString([
            _stringOrNull(order['customer_phone']),
            _stringOrNull(entry['customer_phone']),
          ]) ??
          '',
      distanceKm: _asDouble(order['distance_km']),
      etaMinutes:
          _asInt(order['eta_minutes']) ??
          _asInt(order['estimated_eta_minutes']) ??
          _estimateEtaMinutes(_asDouble(order['distance_km'])),
      payout: payout,
      tip: tip,
      itemsCount: itemsCount,
      itemHighlights: _itemHighlights(items),
      priority: _derivePriority(order: order, payout: payout, tip: tip),
      type: _deriveOrderType(
        order: order,
        isMultiOrder: isMultiOrder,
      ),
      status: deliveryStageFromJson(
        _firstNonEmptyString([
              _stringOrNull(order['status']),
              _stringOrNull(assignment['status']),
              _stringOrNull(entry['status']),
            ]) ??
            'assigned',
      ),
      paymentMethod:
          _firstNonEmptyString([
            _stringOrNull(order['payment_method']),
            _stringOrNull(order['payment_mode']),
            _stringOrNull(entry['payment_method']),
          ]) ??
          'Prepaid',
      orderCode:
          _firstNonEmptyString([
            _stringOrNull(order['order_number']),
            _stringOrNull(order['order_code']),
            _stringOrNull(entry['order_number']),
            _stringOrNull(order['id']),
          ]) ??
          'Pending order',
      customerOtp:
          _firstNonEmptyString([
            _stringOrNull(order['delivery_otp']),
            _stringOrNull(order['customer_otp']),
          ]) ??
          '',
      pickupOtpRequired: _asBool(order['pickup_otp_required']),
      deliveryOtpRequired: _asBool(order['delivery_otp_required']),
      notes:
          _firstNonEmptyString([
            _stringOrNull(order['delivery_notes']),
            _stringOrNull(order['notes']),
            _stringOrNull(entry['notes']),
          ]) ??
          '',
      createdAt:
          _readDateTime(order['created_at']) ??
          _readDateTime(assignment['assigned_at']) ??
          now,
      countdownSeconds: isIncoming ? countdownSeconds : 0,
      isMultiOrder:
          isMultiOrder ||
          _asBool(order['is_multi_order']) ||
          _stringOrNull(order['stack_group_id']) != null,
    );
  }

  DeliveryRecord _mapDeliveryRecord(dynamic rawEntry) {
    final entry = _asMap(rawEntry);
    final order = entry['order'] is Map<String, dynamic>
        ? _asMap(entry['order'])
        : entry;
    final items = _asList(entry['items'] ?? order['items']).map(_asMap).toList();
    final payout =
        _asDouble(entry['net_earning']) +
        _asDouble(entry['cancellation_compensation']);
    final inferredOutcome = _inferOutcome(entry, order);
    final completedAt =
        _readDateTime(order['delivered_at']) ??
        _readDateTime(order['completed_at']) ??
        _readDateTime(entry['created_at']) ??
        DateTime.now();

    return DeliveryRecord(
      id:
          _firstNonEmptyString([
            _stringOrNull(order['id']),
            _stringOrNull(entry['order_id']),
            _stringOrNull(entry['id']),
          ]) ??
          'history-$completedAt',
      restaurantName:
          _firstNonEmptyString([
            _stringOrNull(order['restaurant_name']),
            _stringOrNull(_asMap(order['restaurant'])['name']),
          ]) ??
          _restaurantLabel(order),
      customerName:
          _firstNonEmptyString([
            _stringOrNull(order['customer_name']),
            _stringOrNull(entry['customer_name']),
          ]) ??
          'Customer',
      pickupAddress:
          _firstNonEmptyString([
            _stringOrNull(order['pickup_address']),
            _stringOrNull(order['restaurant_address']),
            _stringOrNull(_asMap(order['restaurant'])['address']),
          ]) ??
          'Pickup location pending',
      dropAddress:
          _firstNonEmptyString([
            _stringOrNull(order['delivery_address']),
            _stringOrNull(order['drop_address']),
          ]) ??
          'Delivery address pending',
      distanceKm: _asDouble(order['distance_km']),
      earnings: payout > 0
          ? payout
          : _asDouble(order['base_payout']) +
                _asDouble(order['distance_payout']) +
                _asDouble(order['waiting_charges']) +
                _asDouble(order['surge_bonus']) +
                _asDouble(order['tip_amount']),
      paymentMethod:
          _firstNonEmptyString([
            _stringOrNull(order['payment_method']),
            _stringOrNull(order['payment_mode']),
          ]) ??
          'Prepaid',
      itemsCount: items.isNotEmpty
          ? items.fold<int>(
              0,
              (sum, item) => sum + (_asInt(item['quantity']) ?? 1),
            )
          : _asInt(order['items_count']) ??
              _asInt(order['item_count']) ??
              _asInt(entry['count']) ??
              0,
      outcome: inferredOutcome,
      completedAt: completedAt,
      notes:
          _firstNonEmptyString([
            _stringOrNull(order['delivery_notes']),
            _stringOrNull(order['notes']),
            _stringOrNull(entry['description']),
          ]) ??
          '',
      timeline: _timelineLabels(_asList(entry['timeline'])),
      durationMinutes:
          _asInt(entry['duration_minutes']) ??
          _asInt(order['duration_minutes']) ??
          _estimateEtaMinutes(_asDouble(order['distance_km'])) + 8,
    );
  }

  AppNotificationItem _mapNotification(dynamic rawEntry) {
    final entry = _asMap(rawEntry);
    return AppNotificationItem(
      id:
          _firstNonEmptyString([
            _stringOrNull(entry['id']),
            _stringOrNull(entry['notification_id']),
          ]) ??
          'notification-${DateTime.now().microsecondsSinceEpoch}',
      title:
          _firstNonEmptyString([
            _stringOrNull(entry['title']),
            _stringOrNull(entry['subject']),
          ]) ??
          'Rider update',
      message:
          _firstNonEmptyString([
            _stringOrNull(entry['body']),
            _stringOrNull(entry['message']),
          ]) ??
          'A new rider update is available.',
      type: notificationTypeFromJson(
        _firstNonEmptyString([
              _stringOrNull(entry['type']),
              _stringOrNull(entry['category']),
            ]) ??
            'order',
      ),
      createdAt: _readDateTime(entry['created_at']) ?? DateTime.now(),
      isUnread: _normalizeStatus(
            _firstNonEmptyString([
              _stringOrNull(entry['status']),
              _stringOrNull(entry['read_status']),
            ]) ??
                'unread',
          ) ==
          'unread',
    );
  }

  RiderReview _mapReview(dynamic rawEntry) {
    final entry = _asMap(rawEntry);
    final createdAt = _readDateTime(entry['created_at']) ?? DateTime.now();
    final comment =
        _firstNonEmptyString([
          _stringOrNull(entry['comment']),
          _stringOrNull(entry['review']),
          _stringOrNull(entry['body']),
        ]) ??
        'Smooth delivery experience.';
    return RiderReview(
      id:
          _firstNonEmptyString([
            _stringOrNull(entry['id']),
            _stringOrNull(entry['review_id']),
          ]) ??
          'review-$createdAt',
      reviewer:
          _firstNonEmptyString([
            _stringOrNull(entry['reviewer_name']),
            _stringOrNull(entry['customer_name']),
            _stringOrNull(entry['restaurant_name']),
            _stringOrNull(entry['actor_name']),
          ]) ??
          'Customer',
      rating: _asDouble(entry['rating']),
      comment: comment,
      createdAt: createdAt,
      highlight:
          _firstNonEmptyString([
            _stringOrNull(entry['highlight']),
            _stringOrNull(entry['tag']),
          ]) ??
          _reviewHighlight(_asDouble(entry['rating']), comment),
    );
  }

  PayoutTransaction _mapWalletTransaction(dynamic rawEntry) {
    final entry = _asMap(rawEntry);
    final createdAt = _readDateTime(entry['created_at']) ?? DateTime.now();
    return PayoutTransaction(
      id:
          _firstNonEmptyString([
            _stringOrNull(entry['id']),
            _stringOrNull(entry['transaction_id']),
          ]) ??
          'wallet-$createdAt',
      title:
          _firstNonEmptyString([
            _stringOrNull(entry['description']),
            _stringOrNull(entry['reference_id']),
          ]) ??
          'Wallet transaction',
      amount: _asDouble(entry['amount']),
      status:
          _firstNonEmptyString([
            _stringOrNull(entry['status']),
            _stringOrNull(entry['type']),
          ]) ??
          'POSTED',
      createdAt: createdAt,
    );
  }

  ShiftSummary _buildShiftSummary({
    required DateTime now,
    required AvailabilityStatus status,
    required Map<String, dynamic> statusData,
    required List<Map<String, dynamic>> todayShift,
    required double activeHoursHint,
  }) {
    final activeShift = _asMap(statusData['active_shift']);
    final shiftStart =
        _readDateTime(activeShift['started_at']) ??
        _earliestDate(
          todayShift
              .map((entry) => _readDateTime(entry['started_at']))
              .whereType<DateTime>(),
        ) ??
        now;
    final shiftEnd =
        _readDateTime(activeShift['ended_at']) ??
        _latestDate(
          todayShift
              .map((entry) => _readDateTime(entry['ended_at']))
              .whereType<DateTime>(),
        ) ??
        shiftStart.add(const Duration(hours: 8));
    final breakMinutes =
        _asInt(activeShift['break_minutes']) ?? _sumBreakMinutes(todayShift);
    final activeHours = activeHoursHint > 0
        ? activeHoursHint
        : _computeActiveHours(now: now, shiftStart: shiftStart, shiftEnd: shiftEnd);

    return ShiftSummary(
      status: status,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      breakMinutes: breakMinutes,
      preferredWindow: _preferredWindowLabel(shiftStart),
      activeHours: activeHours,
      statusMessage: _statusMessage(status),
    );
  }

  List<EarningsPoint> _buildTrendPoints(List<Map<String, dynamic>> records) {
    final buckets = SplayTreeMap<DateTime, double>();
    for (final record in records) {
      final createdAt = _readDateTime(record['created_at']);
      if (createdAt == null) {
        continue;
      }
      final key = DateTime(createdAt.year, createdAt.month, createdAt.day);
      buckets[key] = (buckets[key] ?? 0) + _asDouble(record['net_earning']);
    }

    final points = buckets.entries.toList();
    if (points.isEmpty) {
      return const [
        EarningsPoint(label: 'Mon', amount: 0),
        EarningsPoint(label: 'Tue', amount: 0),
        EarningsPoint(label: 'Wed', amount: 0),
        EarningsPoint(label: 'Thu', amount: 0),
        EarningsPoint(label: 'Fri', amount: 0),
      ];
    }

    return points
        .takeLast(7)
        .map(
          (entry) => EarningsPoint(
            label: DateFormat('E').format(entry.key),
            amount: entry.value,
          ),
        )
        .toList();
  }

  List<EarningsPoint> _buildPayoutHistoryPoints(
    List<Map<String, dynamic>> payoutRequests,
    List<PayoutTransaction> walletTransactions,
  ) {
    if (payoutRequests.isNotEmpty) {
      return payoutRequests
          .take(4)
          .map(
            (entry) => EarningsPoint(
              label: DateFormat('dd MMM').format(
                _readDateTime(entry['requested_at']) ?? DateTime.now(),
              ),
              amount: _asDouble(entry['amount']),
            ),
          )
          .toList();
    }

    return walletTransactions
        .take(4)
        .map(
          (entry) => EarningsPoint(
            label: DateFormat('dd MMM').format(entry.createdAt),
            amount: entry.amount,
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> _extractRecords(Map<String, dynamic> data) {
    return _asList(data['records'])
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _buildCompliments({
    required Map<String, dynamic> performanceData,
    required double averageRating,
  }) {
    final compliments = <String>[];
    if (_asDouble(performanceData['acceptance_rate']) >= 90) {
      compliments.add('Fast acceptance');
    }
    if (_asDouble(performanceData['completion_rate']) >= 95) {
      compliments.add('Reliable handoffs');
    }
    if (averageRating >= 4.7) {
      compliments.add('Top-rated rider');
    }
    if (compliments.isEmpty) {
      compliments.addAll(const ['Consistent service', 'Steady route discipline']);
    }
    return compliments;
  }

  DeliveryOutcome _inferOutcome(
    Map<String, dynamic> entry,
    Map<String, dynamic> order,
  ) {
    final rawStatus = _firstNonEmptyString([
      _stringOrNull(entry['outcome']),
      _stringOrNull(entry['status']),
      _stringOrNull(order['status']),
    ]);
    final normalized = _normalizeStatus(rawStatus ?? 'completed');
    if (normalized.contains('cancel')) {
      return DeliveryOutcome.cancelled;
    }
    if (normalized.contains('fail')) {
      return DeliveryOutcome.failed;
    }
    return DeliveryOutcome.completed;
  }

  List<String> _timelineLabels(List<dynamic> rawTimeline) {
    final mapped = rawTimeline
        .map(_asMap)
        .where((entry) => entry.isNotEmpty)
        .map(
          (entry) => _stageLabel(
            deliveryStageFromJson(
              _stringOrFallback(entry['status'], fallback: 'assigned'),
            ),
          ),
        )
        .toList();
    if (mapped.isNotEmpty) {
      return mapped;
    }
    return const [
      'Assigned',
      'Accepted',
      'Reached restaurant',
      'Picked up',
      'On the way',
      'Arrived at customer',
      'Delivered',
    ];
  }

  int _sumBreakMinutes(List<Map<String, dynamic>> todayShift) {
    var total = 0;
    for (final entry in todayShift) {
      total += _asInt(entry['break_minutes']) ?? 0;
    }
    return total;
  }

  double _computeActiveHours({
    required DateTime now,
    required DateTime shiftStart,
    required DateTime shiftEnd,
  }) {
    final effectiveEnd = shiftEnd.isBefore(shiftStart)
        ? now
        : (shiftEnd.isAfter(now) ? now : shiftEnd);
    final minutes = effectiveEnd.difference(shiftStart).inMinutes;
    return minutes <= 0 ? 0 : minutes / 60;
  }

  double _sumPayoutAmounts(
    List<Map<String, dynamic>> payoutRequests,
    List<String> allowedStatuses,
  ) {
    var total = 0.0;
    for (final entry in payoutRequests) {
      final status = _normalizeStatus(_stringOrFallback(entry['status']));
      if (allowedStatuses.contains(status)) {
        total += _asDouble(entry['amount']);
      }
    }
    return total;
  }

  double _sumByKeys(
    Iterable<Map<String, dynamic>> items,
    List<String> keys,
  ) {
    var total = 0.0;
    for (final item in items) {
      total += keys
          .map((key) => _asDouble(item[key]))
          .firstWhere((value) => value > 0, orElse: () => 0);
    }
    return total;
  }

  OrderPriority _derivePriority({
    required Map<String, dynamic> order,
    required double payout,
    required double tip,
  }) {
    final totalAmount = _asDouble(order['total_amount']);
    final surgeBonus = _asDouble(order['surge_bonus']);
    if (totalAmount >= 1000 || tip >= 40) {
      return OrderPriority.vip;
    }
    if (surgeBonus > 0 || payout >= 80) {
      return OrderPriority.rush;
    }
    return OrderPriority.standard;
  }

  OrderType _deriveOrderType({
    required Map<String, dynamic> order,
    required bool isMultiOrder,
  }) {
    if (isMultiOrder || _stringOrNull(order['stack_group_id']) != null) {
      return OrderType.stacked;
    }
    if (_stringOrNull(order['scheduled_for']) != null ||
        _stringOrNull(order['scheduled_at']) != null) {
      return OrderType.scheduled;
    }
    return OrderType.solo;
  }

  List<String> _itemHighlights(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final quantity = _asInt(item['quantity']) ?? 1;
          final name = _stringOrFallback(item['name'], fallback: 'Item');
          return quantity > 1 ? '${quantity}x $name' : name;
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _reviewHighlight(double rating, String comment) {
    if (rating >= 4.7) {
      return 'Premium service';
    }
    if (rating >= 4.0) {
      return 'Smooth handoff';
    }
    return comment.split('.').first.trim();
  }

  String _displayName(Map<String, dynamic> user) {
    final firstName = _stringOrNull(user['first_name']);
    final lastName = _stringOrNull(user['last_name']);
    final fullName = [firstName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    final email = _stringOrNull(user['email']);
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Rider';
  }

  String _initialsForName(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return 'RD';
    }
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  String _vehicleTypeLabel(String raw) => switch (_normalizeStatus(raw)) {
    'bike' => 'Bike',
    'scooter' => 'Scooter',
    'cycle' => 'Cycle',
    _ => 'Motorbike',
  };

  String _licenseStatus({
    required List<Map<String, dynamic>> documents,
    required Map<String, dynamic> rider,
    required Map<String, dynamic> statusData,
  }) {
    String? documentStatus;
    for (final entry in documents) {
      final candidate = _stringOrNull(entry['status']);
      if (candidate != null && candidate.isNotEmpty) {
        documentStatus = candidate;
        break;
      }
    }
    return _firstNonEmptyString([
          documentStatus,
          _stringOrNull(statusData['kyc_status']),
          _stringOrNull(rider['kyc_status']),
          _stringOrNull(statusData['approval_status']),
          _stringOrNull(rider['approval_status']),
        ]) ??
        'Pending review';
  }

  String _preferredWindowLabel(DateTime shiftStart) {
    final hour = shiftStart.hour;
    if (hour < 11) {
      return 'Breakfast priority band';
    }
    if (hour < 16) {
      return 'Lunch premium band';
    }
    if (hour < 21) {
      return 'Dinner premium band';
    }
    return 'Late-night delivery window';
  }

  String _statusMessage(AvailabilityStatus status) => switch (status) {
    AvailabilityStatus.online => 'Live on priority dispatch lane',
    AvailabilityStatus.busy => 'Stacking nearby premium orders',
    AvailabilityStatus.onBreak => 'Cooling down before the next rush',
    AvailabilityStatus.offline => 'Invisible to dispatch until you resume',
  };

  String _restaurantLabel(Map<String, dynamic> order) {
    final restaurantId = _stringOrNull(order['restaurant_id']);
    if (restaurantId == null || restaurantId.isEmpty) {
      return 'Pickup restaurant';
    }
    return 'Restaurant ${restaurantId.replaceAll('_', '-').toUpperCase()}';
  }

  String _maskedBankAccount(Map<String, dynamic> bankAccount) {
    final rawAccount = _firstNonEmptyString([
      _stringOrNull(bankAccount['account_number']),
      _stringOrNull(bankAccount['masked_account_number']),
      _stringOrNull(bankAccount['iban']),
    ]);
    if (rawAccount == null || rawAccount.isEmpty) {
      return 'Bank account pending';
    }
    if (rawAccount.contains('X') || rawAccount.contains('*')) {
      return rawAccount;
    }
    final suffix = rawAccount.length <= 4
        ? rawAccount
        : rawAccount.substring(rawAccount.length - 4);
    return 'XXXXXX$suffix';
  }

  String? _inferCity(Iterable<String> addresses) {
    for (final address in addresses) {
      final segments = address
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      if (segments.length >= 2) {
        return segments.last;
      }
      if (segments.isNotEmpty) {
        return segments.first;
      }
    }
    return null;
  }

  int _estimateEtaMinutes(double distanceKm) {
    if (distanceKm <= 0) {
      return 12;
    }
    return (distanceKm * 5).round().clamp(8, 60);
  }

  String _stageLabel(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Assigned',
    DeliveryStage.accepted => 'Accepted',
    DeliveryStage.reachedRestaurant => 'Reached restaurant',
    DeliveryStage.pickedUp => 'Picked up',
    DeliveryStage.onTheWay => 'On the way',
    DeliveryStage.reachedCustomer => 'Arrived at customer',
    DeliveryStage.delivered => 'Delivered',
  };

  String get _deviceName {
    if (kIsWeb) {
      return 'Flutter Web Rider';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Flutter Android Rider',
      TargetPlatform.iOS => 'Flutter iPhone Rider',
      TargetPlatform.macOS => 'Flutter macOS Rider',
      TargetPlatform.windows => 'Flutter Windows Rider',
      TargetPlatform.linux => 'Flutter Linux Rider',
      TargetPlatform.fuchsia => 'Flutter Fuchsia Rider',
    };
  }

  Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  List<dynamic> _asList(Object? value) {
    return value is List<dynamic> ? value : const <dynamic>[];
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = _normalizeStatus(value);
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  DateTime? _readDateTime(Object? value) {
    final raw = _stringOrNull(value);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  String _stringOrFallback(Object? value, {String fallback = ''}) {
    return _stringOrNull(value) ?? fallback;
  }

  String? _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _normalizeStatus(String value) {
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  DateTime? _earliestDate(Iterable<DateTime> values) {
    DateTime? result;
    for (final value in values) {
      if (result == null || value.isBefore(result)) {
        result = value;
      }
    }
    return result;
  }

  DateTime? _latestDate(Iterable<DateTime> values) {
    DateTime? result;
    for (final value in values) {
      if (result == null || value.isAfter(result)) {
        result = value;
      }
    }
    return result;
  }
}

extension _TakeLastExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return sublist(length - count);
  }
}


