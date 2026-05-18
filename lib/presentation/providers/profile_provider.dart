import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../domain/entities/app_models.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Profile provider — fetches and holds rider profile independently.
// ---------------------------------------------------------------------------

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, RiderProfile>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<RiderProfile> {
  @override
  Future<RiderProfile> build() => _fetch();

  Future<RiderProfile> _fetch() async {
    final api = ref.read(riderBackendApiProvider);
    try {
      final envelope = await api.profile.me();
      final profile = RiderProfile.fromJson(envelope.data);
      _debugLog(
        'GET /api/v1/rider/profile status=${envelope.statusCode ?? 'unknown'} parsed=true',
      );
      return profile;
    } on ApiException catch (error) {
      _debugLog(
        'GET /api/v1/rider/profile status=${error.statusCode ?? 'unknown'} error=${error.errorCode ?? error.message}',
      );
      if (error.statusCode == 404) {
        return RiderProfile.fromJson(const <String, dynamic>{});
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint('[Rider] $message');
      return true;
    }());
  }
}
