import 'dart:io';

import '../../core/network/api_client.dart';
import '../../domain/entities/onboarding_models.dart';// =============================================================================
// RiderBackendApi — Single entry point for all rider-service API calls.
//
// Every path below matches the Golang backend router (rider-service) exactly.
// Auth endpoints (/auth/...) are handled by the shared user-service.
// =============================================================================

class RiderBackendApi {
  RiderBackendApi(ApiClient client)
    : auth = AuthApi(client),
      rider = RiderApi(client),
      orders = OrdersApi(client),
      delivery = DeliveryApi(client),
      location = LocationApi(client),
      earnings = EarningsApi(client),
      notifications = NotificationsApi(client);

  final AuthApi auth;
  final RiderApi rider;
  final OrdersApi orders;
  final DeliveryApi delivery;
  final LocationApi location;
  final EarningsApi earnings;
  final NotificationsApi notifications;

  /// Legacy accessor aliases used by older providers/screens.
  RiderApi get profile => rider;
  RiderApi get riderProfile => rider;
  OrdersApi get availability => orders; // availability helpers live on RiderApi but kept for compat
}

// =============================================================================
// Auth — handled by shared user-service, NOT rider-service.
// Paths do NOT include /api/v1 since they live on user-service.
// =============================================================================

class AuthApi {
  const AuthApi(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> login({
    required String login,
    required String password,
    required String deviceId,
    required String deviceName,
  }) {
    return _client.postObject(
      '${AppConstants.userApiBaseUrl}/users/login',
      requiresAuth: false,
      body: {
        'email': login,
        'password': password,
      },
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> sendRiderOtp({
    required String login,
  }) {
    return _client.postObject(
      '/auth/rider/otp/send',
      requiresAuth: false,
      body: {'login': login},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> verifyRiderOtp({
    required String login,
    required String otp,
    required String deviceId,
    required String deviceName,
  }) {
    return _client.postObject(
      '/auth/rider/otp/verify',
      requiresAuth: false,
      body: {
        'login': login,
        'otp': otp,
        'device_id': deviceId,
        'device_name': deviceName,
      },
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> signup({
    required Map<String, dynamic> payload,
  }) {
    return _client.postObject(
      '${AppConstants.userApiBaseUrl}/users',
      requiresAuth: false,
      body: payload,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> refreshToken({
    required String refreshToken,
    required String deviceId,
  }) {
    return _client.postObject(
      '/auth/refresh-token',
      requiresAuth: false,
      body: {
        'refresh_token': refreshToken,
        'device_id': deviceId,
      },
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> logout({
    String? refreshToken,
  }) {
    if (refreshToken != null) {
      return _client.postObject(
        '/auth/logout',
        body: {'refresh_token': refreshToken},
      );
    }
    return _client.postObject('/auth/logout-all');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> logoutAll() {
    return _client.postObject('/auth/logout-all');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> forgotPassword({
    required String login,
  }) {
    return _client.postObject(
      '/auth/forgot-password',
      requiresAuth: false,
      body: {'login': login},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  }) {
    return _client.postObject(
      '/auth/reset-password',
      requiresAuth: false,
      body: {
        'login': login,
        'otp': otp,
        'new_password': newPassword,
      },
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> me() {
    return _client.getObject('/auth/me');
  }

  // --- convenience aliases used by providers ---

  Future<ApiEnvelope<Map<String, dynamic>>> sendLoginOtp({
    required String login,
  }) => sendRiderOtp(login: login);

  Future<ApiEnvelope<Map<String, dynamic>>> verifyLoginOtp({
    required String login,
    required String otp,
    String deviceId = '',
    String deviceName = 'Flutter Rider',
  }) => verifyRiderOtp(login: login, otp: otp, deviceId: deviceId, deviceName: deviceName);

  Future<ApiEnvelope<Map<String, dynamic>>> loginWithPassword({
    required String login,
    required String password,
    String deviceId = '',
    String deviceName = 'Flutter Rider',
  }) => this.login(login: login, password: password, deviceId: deviceId, deviceName: deviceName);

  Future<ApiEnvelope<Map<String, dynamic>>> requestPasswordReset({
    required String login,
  }) => forgotPassword(login: login);
}

// =============================================================================
// Rider — profile, vehicle, bank, onboarding, dashboard, availability.
// Backend group: /api/v1/rider
// =============================================================================

class RiderApi {
  const RiderApi(this._client);
  final ApiClient _client;

  // --- Upload ---
  Future<ApiEnvelope<Map<String, dynamic>>> uploadDocument(File file) {
    return _client.postMultipartFile('/api/v1/upload', file: file);
  }

  // --- Profile ---
  Future<ApiEnvelope<Map<String, dynamic>>> me() {
    return _client.getObject('/api/v1/rider/profile');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getProfile() => me();

  Future<ApiEnvelope<Map<String, dynamic>>> updateMe({
    required Map<String, dynamic> payload,
  }) {
    return _client.putObject('/api/v1/rider/profile', body: payload);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateProfile({
    required Map<String, dynamic> payload,
  }) => updateMe(payload: payload);

  // --- Vehicle ---
  Future<ApiEnvelope<Map<String, dynamic>>> updateVehicle({
    required VehiclePayload payload,
  }) {
    return _client.putObject('/api/v1/rider/vehicle', body: payload.toJson());
  }

  // --- Bank Details ---
  Future<ApiEnvelope<Map<String, dynamic>>> updateBankDetails({
    required BankDetailsPayload payload,
  }) {
    return _client.putObject('/api/v1/rider/bank-details', body: payload.toJson());
  }

  /// Legacy alias.
  Future<ApiEnvelope<Map<String, dynamic>>> updateBankAccount({
    required BankDetailsPayload payload,
  }) => updateBankDetails(payload: payload);

  // --- KYC ---
  Future<ApiEnvelope<Map<String, dynamic>>> updateKYC({
    required KycPayload payload,
  }) {
    return _client.putObject('/api/v1/rider/kyc', body: payload.toJson());
  }

  // --- Onboarding ---
  Future<ApiEnvelope<OnboardingStatusInfo>> onboardingStatus() {
    return _client.request<OnboardingStatusInfo>(
      'GET',
      '/api/v1/rider/onboarding-status',
      parser: (data) => OnboardingStatusInfo.fromJson(ApiClient.asMap(data)),
    );
  }

  // --- Dashboard ---
  Future<ApiEnvelope<Map<String, dynamic>>> dashboard() {
    return _client.getObject('/api/v1/rider/dashboard');
  }

  // --- Availability / Go Online / Go Offline ---
  Future<ApiEnvelope<Map<String, dynamic>>> goOnline() {
    return _client.postObject('/api/v1/rider/go-online');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> goOffline() {
    return _client.postObject('/api/v1/rider/go-offline');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getAvailability() {
    return _client.getObject('/api/v1/rider/availability');
  }

  /// Legacy alias: status() → getAvailability()
  Future<ApiEnvelope<Map<String, dynamic>>> status() => getAvailability();
}

// =============================================================================
// Orders — available, active, incoming, assignments, history, detail.
// Backend group: /api/v1/orders
// =============================================================================

class OrdersApi {
  const OrdersApi(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> availableOrders({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getObject(
      '/api/v1/orders/available',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> activeOrder() {
    return _client.getObject('/api/v1/orders/active');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> incomingAssignment() {
    return _client.getObject('/api/v1/orders/incoming');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> acceptAssignment(String assignmentId) {
    return _client.postObject('/api/v1/orders/assignments/$assignmentId/accept');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> rejectAssignment(
    String assignmentId, {
    String? reason,
  }) {
    return _client.postObject(
      '/api/v1/orders/assignments/$assignmentId/reject',
      body: reason == null ? null : {'reason': reason},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> orderDetail(String orderId) {
    return _client.getObject('/api/v1/orders/$orderId');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> orderHistory({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getObject(
      '/api/v1/orders/history',
      queryParameters: queryParameters,
    );
  }

  // --- Legacy aliases used by api_rider_repository / providers ---

  Future<ApiEnvelope<Map<String, dynamic>>> getActiveOrder() => activeOrder();

  Future<ApiEnvelope<Map<String, dynamic>>> getIncomingRequests() =>
      incomingAssignment();

  /// Alias: orderRequests() → incomingAssignment()
  Future<ApiEnvelope<Map<String, dynamic>>> orderRequests() =>
      incomingAssignment();

  Future<ApiEnvelope<Map<String, dynamic>>> acceptOrderRequest(String id) =>
      acceptAssignment(id);

  Future<ApiEnvelope<Map<String, dynamic>>> rejectOrderRequest(
    String id, {
    String? reason,
  }) => rejectAssignment(id, reason: reason);

  Future<ApiEnvelope<Map<String, dynamic>>> order(String orderId) =>
      orderDetail(orderId);
}

// =============================================================================
// Delivery — lifecycle stage transitions.
// Backend group: /api/v1/delivery
// =============================================================================

class DeliveryApi {
  const DeliveryApi(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> arrivedAtRestaurant(String orderId) {
    return _client.postObject('/api/v1/delivery/$orderId/arrived-at-restaurant');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> pickedUp(String orderId) {
    return _client.postObject('/api/v1/delivery/$orderId/picked-up');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> arrivedAtCustomer(String orderId) {
    return _client.postObject('/api/v1/delivery/$orderId/arrived-at-customer');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> delivered(String orderId) {
    return _client.postObject('/api/v1/delivery/$orderId/delivered');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> cancel(
    String orderId, {
    required String reason,
  }) {
    return _client.postObject(
      '/api/v1/delivery/$orderId/cancel',
      body: {'reason': reason},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> fail(
    String orderId, {
    required String reason,
  }) {
    return _client.postObject(
      '/api/v1/delivery/$orderId/failed',
      body: {'reason': reason},
    );
  }

  // --- Legacy aliases used by api_rider_repository ---

  Future<ApiEnvelope<Map<String, dynamic>>> deliver(String orderId) =>
      delivered(orderId);

  Future<ApiEnvelope<Map<String, dynamic>>> markFailed(
    String orderId, {
    required String reason,
  }) => fail(orderId, reason: reason);

  Future<ApiEnvelope<Map<String, dynamic>>> requestCancellation(
    String orderId, {
    required String reason,
  }) => cancel(orderId, reason: reason);
}

// =============================================================================
// Location — GPS updates.
// Backend group: /api/v1/location
// =============================================================================

class LocationApi {
  const LocationApi(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> updateLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) {
    return _client.postObject(
      '/api/v1/location/update',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
      },
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> currentLocation() {
    return _client.getObject('/api/v1/location/current');
  }

  /// Legacy alias.
  Future<ApiEnvelope<Map<String, dynamic>>> latestLocation() =>
      currentLocation();
}

// =============================================================================
// Earnings — summary and history only.
// Backend group: /api/v1/earnings
// =============================================================================

class EarningsApi {
  const EarningsApi(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> summary() {
    return _client.getObject('/api/v1/earnings/summary');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> history({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getObject(
      '/api/v1/earnings/history',
      queryParameters: queryParameters,
    );
  }

  // --- Legacy aliases ---

  Future<ApiEnvelope<Map<String, dynamic>>> getEarningsReport() => summary();
  Future<ApiEnvelope<Map<String, dynamic>>> getPayoutSummary() => summary();
  Future<ApiEnvelope<Map<String, dynamic>>> today() => summary();
  Future<ApiEnvelope<Map<String, dynamic>>> weekly() => summary();
  Future<ApiEnvelope<Map<String, dynamic>>> monthly() => summary();
  Future<ApiEnvelope<Map<String, dynamic>>> wallet() => summary();

  Future<ApiEnvelope<Map<String, dynamic>>> getDeliveryHistory({
    Map<String, dynamic>? queryParameters,
  }) => history(queryParameters: queryParameters);

  /// Stubs for methods that have no backend — return empty data.
  Future<ApiEnvelope<Map<String, dynamic>>> bankAccount() async {
    return const ApiEnvelope(
      success: true,
      message: 'not implemented',
      data: <String, dynamic>{},
    );
  }
}

// =============================================================================
// Notifications — list, mark-read, device token, unread count.
// Backend group: /api/v1/notifications
// =============================================================================

class NotificationsApi {
  const NotificationsApi(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> list({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getObject(
      '/api/v1/notifications',
      queryParameters: queryParameters,
    );
  }

  /// Legacy alias
  Future<ApiEnvelope<Map<String, dynamic>>> notifications({
    Map<String, dynamic>? queryParameters,
  }) => list(queryParameters: queryParameters);

  /// Legacy alias
  Future<ApiEnvelope<Map<String, dynamic>>> getNotifications({
    Map<String, dynamic>? queryParameters,
  }) => list(queryParameters: queryParameters);

  Future<ApiEnvelope<Map<String, dynamic>>> markRead(String id) {
    return _client.request<Map<String, dynamic>>(
      'PATCH',
      '/api/v1/notifications/$id/read',
      parser: (data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> markAllRead() {
    return _client.putObject('/api/v1/notifications/read-all');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> registerDeviceToken({
    required String platform,
    required String pushToken,
  }) {
    return _client.postObject(
      '/api/v1/notifications/device-token',
      body: {
        'platform': platform,
        'device_token': pushToken,
      },
    );
  }

  /// Legacy alias.
  Future<ApiEnvelope<Map<String, dynamic>>> saveDeviceToken({
    required String deviceId,
    required String platform,
    required String token,
  }) => registerDeviceToken(platform: platform, pushToken: token);

  Future<ApiEnvelope<Map<String, dynamic>>> unreadCount() {
    return _client.getObject('/api/v1/notifications/unread-count');
  }
}
