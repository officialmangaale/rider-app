import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Delivery state — active order and stage progression.
// Advancing a delivery stage updates ONLY this provider.
// ---------------------------------------------------------------------------

class DeliveryState {
  const DeliveryState({this.activeOrder, this.queuedOrders = const []});

  final DeliveryOrder? activeOrder;
  final List<DeliveryOrder> queuedOrders;

  bool get hasActiveOrder => activeOrder != null;

  DeliveryState copyWith({
    DeliveryOrder? activeOrder,
    bool clearActiveOrder = false,
    List<DeliveryOrder>? queuedOrders,
  }) {
    return DeliveryState(
      activeOrder: clearActiveOrder ? null : activeOrder ?? this.activeOrder,
      queuedOrders: queuedOrders ?? this.queuedOrders,
    );
  }
}

final deliveryControllerProvider =
    AsyncNotifierProvider<DeliveryController, DeliveryState>(
  DeliveryController.new,
);

class DeliveryController extends AsyncNotifier<DeliveryState> {
  @override
  Future<DeliveryState> build() => _fetch();

  Future<DeliveryState> _fetch() async {
    final api = ref.read(riderBackendApiProvider);

    DeliveryOrder? activeOrder;
    try {
      final envelope = await api.orders.getActiveOrder();
      final data = envelope.data;
      if (data.isNotEmpty) {
        activeOrder = DeliveryOrder.fromJson(data);
      }
    } catch (_) {
      // No active order — that's fine.
    }

    return DeliveryState(activeOrder: activeOrder);
  }

  /// Called after accepting an order — sets it as active delivery.
  void setActiveOrder(DeliveryOrder order) {
    final current = state.valueOrNull ?? const DeliveryState();
    if (current.activeOrder != null) {
      // Already have active, queue the new one.
      state = AsyncValue.data(
        current.copyWith(
          queuedOrders: [...current.queuedOrders, order],
        ),
      );
    } else {
      state = AsyncValue.data(current.copyWith(activeOrder: order));
    }
  }

  /// Advance the active order to the next stage.
  Future<void> advanceActiveOrder({String? otp}) async {
    final current = state.valueOrNull;
    final order = current?.activeOrder;
    if (order == null) return;

    final api = ref.read(riderBackendApiProvider);
    // Map current stage to the correct backend delivery endpoint.
    switch (order.status) {
      case DeliveryStage.assigned:
        // Accept was already done via orders provider.
        break;
      case DeliveryStage.accepted:
        await api.delivery.arrivedAtRestaurant(order.id);
        break;
      case DeliveryStage.reachedRestaurant:
        await api.delivery.pickedUp(order.id);
        break;
      case DeliveryStage.pickedUp:
        await api.delivery.arrivedAtCustomer(order.id);
        break;
      case DeliveryStage.onTheWay:
        await api.delivery.arrivedAtCustomer(order.id);
        break;
      case DeliveryStage.reachedCustomer:
        await api.delivery.delivered(order.id);
        break;
      case DeliveryStage.delivered:
        return; // Already done.
    }

    final nextStageIndex = order.status.index + 1;
    if (nextStageIndex >= DeliveryStage.values.length) {
      // Delivery complete — clear active, promote queued if any.
      final nextQueued = [...current!.queuedOrders];
      final nextActive = nextQueued.isEmpty ? null : nextQueued.removeAt(0);
      state = AsyncValue.data(
        DeliveryState(activeOrder: nextActive, queuedOrders: nextQueued),
      );
      return;
    }

    // Optimistic: advance stage locally.
    final advancedOrder = order.copyWith(
      status: DeliveryStage.values[nextStageIndex],
    );
    state = AsyncValue.data(current!.copyWith(activeOrder: advancedOrder));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

/// Convenience: whether there's an active delivery right now.
final hasActiveDeliveryProvider = Provider<bool>((ref) {
  return ref.watch(deliveryControllerProvider).valueOrNull?.hasActiveOrder ??
      false;
});
