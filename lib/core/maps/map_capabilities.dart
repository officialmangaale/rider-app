import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/google_maps_config.dart';

enum MapCapability { disabled, notConfigured, available, initializationFailed }

final googleMapsConfigProvider = Provider<GoogleMapsConfig>(
  (ref) => GoogleMapsConfig.environment,
);

/// The native side retains the key. Disabled builds never initialize the SDK.
final mapCapabilityProvider = FutureProvider<MapCapability>((ref) async {
  if (!ref.watch(googleMapsConfigProvider).requestsEmbeddedMap) {
    return MapCapability.disabled;
  }
  return const NativeMapConfiguration().initialize();
});

class NativeMapConfiguration {
  const NativeMapConfiguration();
  static const channel = MethodChannel('com.mangaale/maps_configuration');

  Future<MapCapability> initialize() async {
    try {
      final available = await channel
          .invokeMethod<bool>('initialize', {'enabled': true})
          .timeout(const Duration(seconds: 3));
      return available == true
          ? MapCapability.available
          : MapCapability.notConfigured;
    } on MissingPluginException {
      return MapCapability.notConfigured;
    } catch (_) {
      return MapCapability.initializationFailed;
    }
  }
}
