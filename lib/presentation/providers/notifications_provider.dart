import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Notifications provider — granular mark-read without full app refresh.
// ---------------------------------------------------------------------------

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotificationItem>>(
  NotificationsController.new,
);

class NotificationsController
    extends AsyncNotifier<List<AppNotificationItem>> {
  @override
  Future<List<AppNotificationItem>> build() => _fetch();

  Future<List<AppNotificationItem>> _fetch() async {
    final api = ref.read(riderBackendApiProvider);
    final envelope = await api.notifications.getNotifications();
    return (envelope.data as List<dynamic>)
        .map(
          (item) =>
              AppNotificationItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Mark a single notification read — optimistic local update.
  Future<void> markRead(String id) async {
    final api = ref.read(riderBackendApiProvider);
    await api.notifications.markRead(id);

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current
            .map((n) => n.id == id ? n.copyWith(isUnread: false) : n)
            .toList(),
      );
    }
  }

  /// Mark all notifications read — optimistic local update.
  Future<void> markAllRead() async {
    final api = ref.read(riderBackendApiProvider);
    await api.notifications.markAllRead();

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.map((n) => n.copyWith(isUnread: false)).toList(),
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

/// Unread notification count — derived provider.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsControllerProvider).valueOrNull ?? [];
  return notifications.where((n) => n.isUnread).length;
});
