import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/app_preferences.dart';
import '../../../presentation/providers/core_providers.dart';
import '../models/delivery_models.dart';
import '../services/rider_delivery_api_service.dart';
import '../services/rider_location_service.dart';
import '../services/rider_socket_service.dart';

// Providers for the new services
final riderDeliveryApiServiceProvider = Provider<RiderDeliveryApiService>((ref) {
  return RiderDeliveryApiService(ref.watch(apiClientProvider));
});

final riderLocationServiceProvider = Provider<RiderLocationService>((ref) {
  return RiderLocationService(
    onLocationUpdate: (position) {
      ref.read(riderDeliveryControllerProvider.notifier)._onLocationUpdated(position.latitude, position.longitude);
    },
  );
});

final riderSocketServiceProvider = Provider<RiderSocketService>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  return RiderSocketService(
    token: prefs.accessToken ?? '',
    onDeliveryOrderRequest: (request) {
      ref.read(riderDeliveryControllerProvider.notifier)._onNewDeliveryRequest(request);
    },
    onOrderRequestExpired: (requestId, orderId) {
      ref.read(riderDeliveryControllerProvider.notifier)._onRequestExpired(requestId);
    },
    onOrderAssignedToOther: (requestId, orderId) {
      ref.read(riderDeliveryControllerProvider.notifier)._onRequestAssignedToOther(requestId);
    },
  );
});

class RiderDeliveryState {
  const RiderDeliveryState({
    this.isOnline = false,
    this.isAvailable = false,
    this.socketConnected = false,
    this.pendingRequests = const [],
    this.activeOrderId,
    this.activeOrder,
    this.seenRequestIds = const {},
  });

  final bool isOnline;
  final bool isAvailable;
  final bool socketConnected;
  final List<RiderOrderRequestModel> pendingRequests;
  final int? activeOrderId;
  final ActiveDeliveryOrderModel? activeOrder;
  final Set<int> seenRequestIds; // To avoid duplicate modals

  RiderDeliveryState copyWith({
    bool? isOnline,
    bool? isAvailable,
    bool? socketConnected,
    List<RiderOrderRequestModel>? pendingRequests,
    int? activeOrderId,
    bool clearActiveOrderId = false,
    ActiveDeliveryOrderModel? activeOrder,
    bool clearActiveOrder = false,
    Set<int>? seenRequestIds,
  }) {
    return RiderDeliveryState(
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      socketConnected: socketConnected ?? this.socketConnected,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeOrderId: clearActiveOrderId ? null : (activeOrderId ?? this.activeOrderId),
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      seenRequestIds: seenRequestIds ?? this.seenRequestIds,
    );
  }
}

final riderDeliveryControllerProvider = NotifierProvider<RiderDeliveryController, RiderDeliveryState>(
  RiderDeliveryController.new,
);

class RiderDeliveryController extends Notifier<RiderDeliveryState> {
  @override
  RiderDeliveryState build() {
    return const RiderDeliveryState();
  }

  Future<void> toggleOnline(bool online) async {
    final api = ref.read(riderDeliveryApiServiceProvider);
    final location = ref.read(riderLocationServiceProvider);
    final socket = ref.read(riderSocketServiceProvider);

    try {
      final response = await api.updateRiderAvailability(
        isOnline: online,
        isAvailable: online && state.activeOrderId == null,
      );

      final data = response.data;
      state = state.copyWith(
        isOnline: data.isOnline,
        isAvailable: data.isAvailable,
        activeOrderId: data.currentOrderId,
      );

      if (data.isOnline) {
        location.startTracking(isActiveDelivery: data.currentOrderId != null);
        socket.connect();
        state = state.copyWith(socketConnected: true);
        await refreshPendingRequests();
        if (data.currentOrderId != null) {
          await fetchActiveOrder(data.currentOrderId!);
        }
      } else {
        if (state.activeOrderId == null) {
          location.stopTracking();
          socket.disconnect();
          state = state.copyWith(socketConnected: false, pendingRequests: []);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  void _onLocationUpdated(double lat, double lng) {
    if (!state.isOnline) return;
    ref.read(riderDeliveryApiServiceProvider).updateRiderLocation(
      latitude: lat,
      longitude: lng,
    ).catchError((_) {}); // fail silently for location sync
  }

  void _onNewDeliveryRequest(RiderOrderRequestModel request) {
    if (state.seenRequestIds.contains(request.requestId)) return;
    
    final updatedSeen = Set<int>.from(state.seenRequestIds)..add(request.requestId);
    state = state.copyWith(
      pendingRequests: [...state.pendingRequests, request],
      seenRequestIds: updatedSeen,
    );
  }

  void _onRequestExpired(int requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests.where((r) => r.requestId != requestId).toList(),
    );
  }

  void _onRequestAssignedToOther(int requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests.where((r) => r.requestId != requestId).toList(),
    );
  }

  Future<void> refreshPendingRequests() async {
    try {
      final response = await ref.read(riderDeliveryApiServiceProvider).getPendingOrderRequests();
      state = state.copyWith(pendingRequests: response.data);
    } catch (_) {}
  }

  Future<void> fetchActiveOrder(int orderId) async {
    try {
      final response = await ref.read(riderDeliveryApiServiceProvider).getActiveDeliveryOrder(orderId);
      state = state.copyWith(activeOrder: response.data, activeOrderId: orderId);
      ref.read(riderLocationServiceProvider).startTracking(isActiveDelivery: true);
    } catch (_) {}
  }

  Future<void> acceptRequest(int requestId) async {
    try {
      final response = await ref.read(riderDeliveryApiServiceProvider).acceptOrderRequest(requestId);
      state = state.copyWith(
        activeOrder: response.data,
        activeOrderId: response.data.orderId,
        isAvailable: false,
        pendingRequests: state.pendingRequests.where((r) => r.requestId != requestId).toList(),
      );
      ref.read(riderLocationServiceProvider).startTracking(isActiveDelivery: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRequest(int requestId) async {
    try {
      await ref.read(riderDeliveryApiServiceProvider).rejectOrderRequest(requestId);
      state = state.copyWith(
        pendingRequests: state.pendingRequests.where((r) => r.requestId != requestId).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDeliveryStatus(String newStatus) async {
    if (state.activeOrderId == null) return;
    
    try {
      await ref.read(riderDeliveryApiServiceProvider).updateDeliveryStatus(
        orderId: state.activeOrderId!,
        deliveryStatus: newStatus,
      );
      
      if (newStatus == 'delivered') {
        state = state.copyWith(
          clearActiveOrder: true,
          clearActiveOrderId: true,
          isAvailable: state.isOnline, // Becomes available if still online
        );
        ref.read(riderLocationServiceProvider).startTracking(isActiveDelivery: false); // Back to idle tracking
      } else {
        await fetchActiveOrder(state.activeOrderId!);
      }
    } catch (e) {
      rethrow;
    }
  }
}
