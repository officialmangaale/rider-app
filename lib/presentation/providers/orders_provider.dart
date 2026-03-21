import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Orders state — incoming assignments only (no queued orders on backend).
// Backend: GET /api/v1/orders/incoming, POST assignments/:id/accept|reject.
// ---------------------------------------------------------------------------

class OrdersState {
  const OrdersState({
    this.incoming = const [],
    this.queued = const [],
  });

  final List<DeliveryOrder> incoming;
  final List<DeliveryOrder> queued;

  OrdersState copyWith({
    List<DeliveryOrder>? incoming,
    List<DeliveryOrder>? queued,
  }) {
    return OrdersState(
      incoming: incoming ?? this.incoming,
      queued: queued ?? this.queued,
    );
  }
}

final ordersControllerProvider =
    AsyncNotifierProvider<OrdersController, OrdersState>(
  OrdersController.new,
);

class OrdersController extends AsyncNotifier<OrdersState> {
  @override
  Future<OrdersState> build() => _fetch();

  Future<OrdersState> _fetch() async {
    final api = ref.read(riderBackendApiProvider);

    // Fetch incoming assignment (backend returns single or null)
    List<DeliveryOrder> incomingList = [];
    try {
      final envelope = await api.orders.incomingAssignment();
      final data = envelope.data;
      if (data.isNotEmpty && data['assignment'] != null) {
        final merged = <String, dynamic>{
          ...data['order'] as Map<String, dynamic>? ?? {},
          'assignment': data['assignment'],
        };
        incomingList = [DeliveryOrder.fromJson(merged)];
      }
    } catch (_) {
      // No incoming — that's fine.
    }

    return OrdersState(incoming: incomingList);
  }

  /// Accept an order — removes from incoming, does NOT cause full refresh.
  Future<void> acceptOrder(String assignmentId) async {
    final api = ref.read(riderBackendApiProvider);
    await api.orders.acceptAssignment(assignmentId);

    // Optimistic: remove from incoming list locally.
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          incoming: current.incoming
              .where((o) => o.assignmentId != assignmentId)
              .toList(),
        ),
      );
    }
  }

  /// Reject an order — removes from incoming, does NOT cause full refresh.
  Future<void> rejectOrder(String assignmentId, {String? reason}) async {
    final api = ref.read(riderBackendApiProvider);
    await api.orders.rejectAssignment(assignmentId, reason: reason);

    // Optimistic: remove from incoming list locally.
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          incoming: current.incoming
              .where((o) => o.assignmentId != assignmentId)
              .toList(),
        ),
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

/// Convenience provider for incoming order count (used in badges).
final incomingOrderCountProvider = Provider<int>((ref) {
  return ref.watch(ordersControllerProvider).valueOrNull?.incoming.length ?? 0;
});
