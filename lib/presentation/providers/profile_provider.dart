import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final envelope = await api.profile.me();
    return RiderProfile.fromJson(envelope.data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}
