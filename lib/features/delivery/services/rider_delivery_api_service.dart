import '../../../core/network/api_client.dart';
import '../models/delivery_models.dart';

class RiderDeliveryApiService {
  const RiderDeliveryApiService(this._client);
  final ApiClient _client;

  Future<ApiEnvelope<RiderAvailabilityModel>> updateRiderAvailability({
    required bool isOnline,
    required bool isAvailable,
  }) {
    return _client.request<RiderAvailabilityModel>(
      'POST',
      '/riders/availability',
      body: {
        'is_online': isOnline,
        'is_available': isAvailable,
      },
      parser: (data) => RiderAvailabilityModel.fromJson(ApiClient.asMap(data)),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateRiderLocation({
    required double latitude,
    required double longitude,
  }) {
    return _client.postObject(
      '/riders/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<ApiEnvelope<List<RiderOrderRequestModel>>> getPendingOrderRequests() {
    return _client.request<List<RiderOrderRequestModel>>(
      'GET',
      '/riders/order-requests',
      parser: (data) {
        if (data is List) {
          return data.map((item) => RiderOrderRequestModel.fromJson(ApiClient.asMap(item))).toList();
        }
        return [];
      },
    );
  }

  Future<ApiEnvelope<ActiveDeliveryOrderModel>> acceptOrderRequest(int requestId) {
    return _client.request<ActiveDeliveryOrderModel>(
      'POST',
      '/riders/order-requests/$requestId/accept',
      parser: (data) => ActiveDeliveryOrderModel.fromJson(ApiClient.asMap(data)),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> rejectOrderRequest(int requestId) {
    return _client.postObject(
      '/riders/order-requests/$requestId/reject',
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> updateDeliveryStatus({
    required int orderId,
    required String deliveryStatus,
  }) {
    return _client.postObject(
      '/riders/orders/$orderId/status',
      body: {
        'delivery_status': deliveryStatus,
      },
    );
  }

  Future<ApiEnvelope<ActiveDeliveryOrderModel>> getActiveDeliveryOrder(int orderId) {
    return _client.request<ActiveDeliveryOrderModel>(
      'GET',
      '/riders/orders/$orderId/active',
      parser: (data) => ActiveDeliveryOrderModel.fromJson(ApiClient.asMap(data)),
    );
  }
}
