import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';
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
    final envelope = await api.rider.getAvailability();
    final data = envelope.data;

    final isAvailable = data['is_available'] == true;
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
      'shiftEnd':
          DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      'breakMinutes': 0,
      'preferredWindow': '',
      'activeHours': 0.0,
      'statusMessage': isAvailable ? 'You are online' : 'You are offline',
    });
  }

  /// Toggle availability — updates only this provider's state.
  Future<void> setStatus(AvailabilityStatus newStatus) async {
    final api = ref.read(riderBackendApiProvider);
    switch (newStatus) {
      case AvailabilityStatus.online:
      case AvailabilityStatus.busy:
        await api.rider.goOnline();
        break;
      case AvailabilityStatus.offline:
      case AvailabilityStatus.onBreak:
        await api.rider.goOffline();
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
