import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../domain/entities/app_models.dart';
import '../../features/delivery/providers/rider_delivery_provider.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Availability provider — online/offline status.
// Backend has: GET /api/v1/rider/availability, POST go-online, POST go-offline.
// No shifts or breaks.
// ---------------------------------------------------------------------------

final availabilityControllerProvider =
    AsyncNotifierProvider<AvailabilityController, ShiftSummary>(
      AvailabilityController.new,
    );

class AvailabilityController extends AsyncNotifier<ShiftSummary> {
  @override
  Future<ShiftSummary> build() => _fetch();

  Future<ShiftSummary> _fetch() async {
    final api = ref.read(riderBackendApiProvider);
    try {
      _debugAvailability('GET /api/v1/rider/availability state=fetching');
      final envelope = await api.rider.getAvailability();
      final data = envelope.data;
      _debugAvailability(
        'GET /api/v1/rider/availability status=${envelope.statusCode ?? 'unknown'} '
        'responseKeys=${data.keys.join(',')}',
      );

      final isAvailable =
          data['is_available'] == true || data['is_is_available'] == true;
      final onTrip = data['on_trip'] == true;

      String statusStr;
      if (onTrip) {
        statusStr = 'busy';
      } else if (isAvailable) {
        statusStr = 'online';
      } else {
        statusStr = 'offline';
      }

      return ShiftSummary.fromJson({
        'status': statusStr,
        'shiftStart': DateTime.now().toIso8601String(),
        'shiftEnd': DateTime.now()
            .add(const Duration(hours: 10))
            .toIso8601String(),
        'breakMinutes': 0,
        'preferredWindow': '',
        'activeHours': 0.0,
        'statusMessage': isAvailable ? 'You are online' : 'You are offline',
      });
    } on ApiException catch (error) {
      _debugAvailability(
        'GET /api/v1/rider/availability status=${error.statusCode ?? 'unknown'} '
        'error=${error.errorCode ?? error.message}',
      );
      rethrow;
    }
  }

  /// Toggle availability — updates only this provider's state.
  Future<void> setStatus(AvailabilityStatus newStatus) async {
    switch (newStatus) {
      case AvailabilityStatus.online:
      case AvailabilityStatus.busy:
        await ref
            .read(riderDeliveryControllerProvider.notifier)
            .toggleOnline(true);
        break;
      case AvailabilityStatus.offline:
      case AvailabilityStatus.onBreak:
        await ref
            .read(riderDeliveryControllerProvider.notifier)
            .toggleOnline(false);
        break;
    }

    // Optimistic local update: mutate the current state's status field.
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(status: newStatus));
    } else {
      state = await AsyncValue.guard(() => _fetch());
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

/// Quick read of whether rider is currently online.
final isRiderOnlineProvider = Provider<bool>((ref) {
  final shift = ref.watch(availabilityControllerProvider).valueOrNull;
  return shift?.status == AvailabilityStatus.online;
});

void _debugAvailability(String message) {
  assert(() {
    debugPrint('[RiderAvailability] $message');
    return true;
  }());
}
