import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';

// ---------------------------------------------------------------------------
// Support provider — FAQs loaded from local assets (no backend endpoint).
// ---------------------------------------------------------------------------

final supportControllerProvider =
    AsyncNotifierProvider<SupportController, List<SupportFaq>>(
  SupportController.new,
);

class SupportController extends AsyncNotifier<List<SupportFaq>> {
  @override
  Future<List<SupportFaq>> build() => _fetch();

  Future<List<SupportFaq>> _fetch() async {
    // Backend has no support endpoint — return empty for now.
    // In the full bootstrap flow, FAQs come from local asset mock data.
    return const [];
  }

  /// Create a support ticket — stub since backend has no support endpoint yet.
  Future<void> createTicket({
    required String subject,
    required String description,
    String? orderId,
  }) async {
    // Backend does not have a support endpoint yet.
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}
