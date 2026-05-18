import '../../../core/network/api_client.dart';
import '../models/delivery_models.dart';

class RiderDeliveryApiService {
  const RiderDeliveryApiService(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<RiderAvailabilityModel>> updateRiderAvailability({
    required bool isOnline,
  }) {
    return _client.request<RiderAvailabilityModel>(
      'POST',
      isOnline ? '/api/v1/rider/go-online' : '/api/v1/rider/go-offline',
      parser: (data) => RiderAvailabilityModel.fromJson(ApiClient.asMap(data)),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateRiderLocation({
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

  Future<ApiEnvelope<List<RiderOrderRequestModel>>> getPendingOrderRequests() {
    return _client.request<List<RiderOrderRequestModel>>(
      'GET',
      '/riders/order-requests',
      parser: (data) {
        return _extractList(data)
            .map(
              (item) => RiderOrderRequestModel.fromJson(ApiClient.asMap(item)),
            )
            .toList();
      },
    );
  }

  Future<ApiEnvelope<ActiveDeliveryOrderModel>> acceptOrderRequest(
    int requestId,
  ) {
    return _client.request<ActiveDeliveryOrderModel>(
      'POST',
      '/riders/order-requests/$requestId/accept',
      parser: (data) => ActiveDeliveryOrderModel.fromJson(_extractObject(data)),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> rejectOrderRequest(int requestId) {
    return _client.postObject('/riders/order-requests/$requestId/reject');
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateDeliveryStatus({
    required int orderId,
    required String deliveryStatus,
  }) {
    return _client.postObject(
      '/riders/orders/$orderId/status',
      body: {'delivery_status': deliveryStatus},
    );
  }

  Future<ApiEnvelope<ActiveDeliveryOrderModel>> getActiveDeliveryOrder(
    int orderId,
  ) {
    return _client.request<ActiveDeliveryOrderModel>(
      'GET',
      '/riders/orders/$orderId/active',
      parser: (data) => ActiveDeliveryOrderModel.fromJson(_extractObject(data)),
    );
  }

  static List<dynamic> _extractList(Object? data) {
    if (data is List) {
      return data;
    }
    final map = ApiClient.asMap(data);
    for (final key in const ['items', 'requests', 'order_requests', 'data']) {
      final value = map[key];
      if (value is List) {
        return value;
      }
      if (value is Map) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return const <dynamic>[];
  }

  static Map<String, dynamic> _extractObject(Object? data) {
    final map = ApiClient.asMap(data);
    for (final key in const ['order', 'delivery', 'data']) {
      final nested = ApiClient.asMap(map[key]);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    return map;
  }
}
