import '../../core/network/api_client.dart';

class RiderBackendApi {
  RiderBackendApi(ApiClient client)
    : auth = AuthApi(client),
      riderProfile = RiderProfileApi(client),
      availability = AvailabilityApi(client),
      orders = OrdersApi(client),
      otpVerification = OtpVerificationApi(client),
      liveLocation = LiveLocationApi(client),
      earnings = EarningsApi(client),
      ratings = RatingsApi(client),
      notifications = NotificationsApi(client),
      support = SupportApi(client),
      admin = AdminApi(client);

  final AuthApi auth;
  final RiderProfileApi riderProfile;
  final AvailabilityApi availability;
  final OrdersApi orders;
  final OtpVerificationApi otpVerification;
  final LiveLocationApi liveLocation;
  final EarningsApi earnings;
  final RatingsApi ratings;
  final NotificationsApi notifications;
  final SupportApi support;
  final AdminApi admin;
}

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
      '/auth/rider/login',
      requiresAuth: false,
      body: {
        'login': login,
        'password': password,
        'device_id': deviceId,
        'device_name': deviceName,
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
    required String refreshToken,
  }) {
    return _client.postObject(
      '/auth/logout',
      body: {'refresh_token': refreshToken},
    );
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
}

class RiderProfileApi {
  const RiderProfileApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> me() {
    return _client.getObject('/riders/me');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateMe({
    required Map<String, dynamic> payload,
  }) {
    return _client.putObject('/riders/me', body: payload);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updatePhoto({
    required String photoUrl,
  }) {
    return _client.putObject(
      '/riders/me/photo',
      body: {'photo_url': photoUrl},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateVehicle({
    required Map<String, dynamic> payload,
  }) {
    return _client.putObject('/riders/me/vehicle', body: payload);
  }

  Future<ApiEnvelope<List<dynamic>>> updateDocuments({
    required List<Map<String, dynamic>> documents,
  }) {
    return _client.putList(
      '/riders/me/documents',
      body: {'documents': documents},
    );
  }

  Future<ApiEnvelope<List<dynamic>>> documents({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/documents',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateBankAccount({
    required Map<String, dynamic> payload,
  }) {
    return _client.putObject('/riders/me/bank-account', body: payload);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> status() {
    return _client.getObject('/riders/me/status');
  }
}

class AvailabilityApi {
  const AvailabilityApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> goOnline() {
    return _client.postObject('/riders/me/go-online');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> goOffline({String? reason}) {
    return _client.postObject(
      '/riders/me/go-offline',
      body: reason == null ? null : {'reason': reason},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> startBreak({String? reason}) {
    return _client.postObject(
      '/riders/me/break/start',
      body: reason == null ? null : {'reason': reason},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> endBreak() {
    return _client.postObject('/riders/me/break/end');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> startShift({
    Map<String, dynamic>? payload,
  }) {
    return _client.postObject('/riders/me/shift/start', body: payload);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> endShift({
    Map<String, dynamic>? payload,
  }) {
    return _client.postObject('/riders/me/shift/end', body: payload);
  }

  Future<ApiEnvelope<List<dynamic>>> todayShift({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/shift/today',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<List<dynamic>>> shiftHistory({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/shift/history',
      queryParameters: queryParameters,
    );
  }
}

class OrdersApi {
  const OrdersApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<List<dynamic>>> orderRequests({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/order-requests',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> orderRequest(String id) {
    return _client.getObject('/riders/me/order-requests/$id');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> acceptOrderRequest(String id) {
    return _client.postObject('/riders/me/order-requests/$id/accept');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> rejectOrderRequest(
    String id, {
    String? reason,
  }) {
    return _client.postObject(
      '/riders/me/order-requests/$id/reject',
      body: reason == null ? null : {'reason': reason},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> activeOrder() {
    return _client.getObject('/riders/me/active-order');
  }

  Future<ApiEnvelope<List<dynamic>>> assignedOrders({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/orders/assigned',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<List<dynamic>>> orderHistory({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/orders/history',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> order(String orderId) {
    return _client.getObject('/riders/me/orders/$orderId');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> arrivedAtRestaurant(String orderId) {
    return _client.postObject(
      '/riders/me/orders/$orderId/arrived-at-restaurant',
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> pickedUp(String orderId) {
    return _client.postObject('/riders/me/orders/$orderId/picked-up');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> startDelivery(String orderId) {
    return _client.postObject('/riders/me/orders/$orderId/start-delivery');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> arrivedAtCustomer(String orderId) {
    return _client.postObject(
      '/riders/me/orders/$orderId/arrived-at-customer',
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> deliver(String orderId) {
    return _client.postObject('/riders/me/orders/$orderId/deliver');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> markFailed(
    String orderId, {
    required String reason,
  }) {
    return _client.postObject(
      '/riders/me/orders/$orderId/failed',
      body: {'reason': reason},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> requestCancellation(
    String orderId, {
    required String reason,
  }) {
    return _client.postObject(
      '/riders/me/orders/$orderId/cancel-request',
      body: {'reason': reason},
    );
  }

  Future<ApiEnvelope<List<dynamic>>> timeline(String orderId) {
    return _client.getList('/riders/me/orders/$orderId/timeline');
  }
}

class OtpVerificationApi {
  const OtpVerificationApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> verifyPickupOtp({
    required String orderId,
    required String otp,
  }) {
    return _client.postObject(
      '/riders/me/orders/$orderId/verify-pickup-otp',
      body: {'otp': otp},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> verifyDeliveryOtp({
    required String orderId,
    required String otp,
  }) {
    return _client.postObject(
      '/riders/me/orders/$orderId/verify-delivery-otp',
      body: {'otp': otp},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> resendDeliveryOtp(String orderId) {
    return _client.postObject('/orders/$orderId/resend-delivery-otp');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> resendPickupOtp(String orderId) {
    return _client.postObject('/orders/$orderId/resend-pickup-otp');
  }
}

class LiveLocationApi {
  const LiveLocationApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> updateLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? speedKph,
    double? headingDegrees,
    num? batteryLevel,
    String? source,
    String? recordedAt,
  }) {
    return _client.postObject(
      '/riders/me/location/update',
      body: {
        'order_id': orderId,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
        if (speedKph != null) 'speed_kph': speedKph,
        if (headingDegrees != null) 'heading_degrees': headingDegrees,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (source != null) 'source': source,
        if (recordedAt != null) 'recorded_at': recordedAt,
      },
    );
  }

  Future<ApiEnvelope<List<dynamic>>> bulkUpdateLocation({
    required List<Map<String, dynamic>> points,
  }) {
    return _client.postList(
      '/riders/me/location/bulk-update',
      body: {'points': points},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> latestLocation() {
    return _client.getObject('/riders/me/location/latest');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> tracking(String orderId) {
    return _client.getObject('/orders/$orderId/tracking');
  }

  Future<ApiEnvelope<List<dynamic>>> routeHistory(
    String orderId, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/routes/$orderId',
      queryParameters: queryParameters,
    );
  }
}

class EarningsApi {
  const EarningsApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> today() {
    return _client.getObject('/riders/me/earnings/today');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> weekly() {
    return _client.getObject('/riders/me/earnings/weekly');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> monthly() {
    return _client.getObject('/riders/me/earnings/monthly');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> summary() {
    return _client.getObject('/riders/me/earnings/summary');
  }

  Future<ApiEnvelope<List<dynamic>>> history({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/earnings/history',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<List<dynamic>>> incentives({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/incentives',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<List<dynamic>>> bonusHistory({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/bonus-history',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> wallet() {
    return _client.getObject('/riders/me/wallet');
  }

  Future<ApiEnvelope<List<dynamic>>> walletTransactions({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/wallet/transactions',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<List<dynamic>>> payouts({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList('/riders/me/payouts', queryParameters: queryParameters);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> payout(String id) {
    return _client.getObject('/riders/me/payouts/$id');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> requestPayout({
    required num amount,
  }) {
    return _client.postObject(
      '/riders/me/payouts/request',
      body: {'amount': amount},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> bankAccount() {
    return _client.getObject('/riders/me/bank-account');
  }
}

class RatingsApi {
  const RatingsApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> summary() {
    return _client.getObject('/riders/me/ratings/summary');
  }

  Future<ApiEnvelope<List<dynamic>>> reviews({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList('/riders/me/reviews', queryParameters: queryParameters);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> performanceScore() {
    return _client.getObject('/riders/me/performance-score');
  }
}

class NotificationsApi {
  const NotificationsApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<List<dynamic>>> notifications({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/notifications',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> markRead(String id) {
    return _client.putObject('/riders/me/notifications/$id/read');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> markAllRead() {
    return _client.putObject('/riders/me/notifications/read-all');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> saveDeviceToken({
    required String deviceId,
    required String platform,
    required String token,
  }) {
    return _client.postObject(
      '/riders/me/device-token',
      body: {
        'device_id': deviceId,
        'platform': platform,
        'token': token,
      },
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> deleteDeviceToken({
    required String deviceId,
  }) {
    return _client.deleteObject(
      '/riders/me/device-token',
      queryParameters: {'device_id': deviceId},
    );
  }
}

class SupportApi {
  const SupportApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<Map<String, dynamic>>> createTicket({
    required Map<String, dynamic> payload,
  }) {
    return _client.postObject('/riders/me/support-tickets', body: payload);
  }

  Future<ApiEnvelope<List<dynamic>>> tickets({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/riders/me/support-tickets',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> ticket(String id) {
    return _client.getObject('/riders/me/support-tickets/$id');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> reply({
    required String ticketId,
    required String message,
  }) {
    return _client.postObject(
      '/riders/me/support-tickets/$ticketId/reply',
      body: {'message': message},
    );
  }
}

class AdminApi {
  const AdminApi(this._client);

  final ApiClient _client;

  Future<ApiEnvelope<List<dynamic>>> riders({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList('/admin/riders', queryParameters: queryParameters);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> rider(String id) {
    return _client.getObject('/admin/riders/$id');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> createRider({
    required Map<String, dynamic> payload,
  }) {
    return _client.postObject('/admin/riders', body: payload);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateRider({
    required String id,
    required Map<String, dynamic> payload,
  }) {
    return _client.putObject('/admin/riders/$id', body: payload);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateRiderStatus({
    required String id,
    required String status,
  }) {
    return _client.putObject(
      '/admin/riders/$id/status',
      body: {'status': status},
    );
  }

  Future<ApiEnvelope<List<dynamic>>> unassignedOrders({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/admin/orders/unassigned',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> assignRider({
    required String orderId,
    required String riderId,
  }) {
    return _client.postObject(
      '/admin/orders/$orderId/assign-rider',
      body: {'rider_id': riderId},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> reassignRider({
    required String orderId,
    required String riderId,
  }) {
    return _client.postObject(
      '/admin/orders/$orderId/reassign-rider',
      body: {'rider_id': riderId},
    );
  }

  Future<ApiEnvelope<List<dynamic>>> liveOrders({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList('/admin/orders/live', queryParameters: queryParameters);
  }

  Future<ApiEnvelope<List<dynamic>>> liveRiderStatus({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList(
      '/admin/riders/live-status',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> riderAnalytics({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getObject(
      '/admin/analytics/riders',
      queryParameters: queryParameters,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> config() {
    return _client.getObject('/admin/config');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateConfig({
    required Map<String, dynamic> payload,
  }) {
    return _client.putObject('/admin/config', body: payload);
  }

  Future<ApiEnvelope<List<dynamic>>> payouts({
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.getList('/admin/payouts', queryParameters: queryParameters);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> approvePayout(String id) {
    return _client.postObject('/admin/payouts/$id/approve');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> rejectPayout({
    required String id,
    required String reason,
  }) {
    return _client.postObject(
      '/admin/payouts/$id/reject',
      queryParameters: {'reason': reason},
    );
  }
}


