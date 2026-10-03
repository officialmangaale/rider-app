import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/core/config/google_maps_config.dart';
import 'package:rydex_rider/core/maps/map_capabilities.dart';
import 'package:rydex_rider/core/services/map_launcher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var calls = 0;
  var nativeReady = false;
  setUp(() {
    calls = 0;
    nativeReady = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeMapConfiguration.channel, (call) async {
          calls++;
          expect(call.method, 'initialize');
          expect(call.arguments, {'enabled': true});
          return nativeReady;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeMapConfiguration.channel, null),
  );

  Future<MapCapability> capability(GoogleMapsConfig config) async {
    final container = ProviderContainer(
      overrides: [googleMapsConfigProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);
    return container.read(mapCapabilityProvider.future);
  }

  test(
    'disabled flags skip native initialization even with a configured key',
    () async {
      nativeReady = true;
      expect(
        await capability(const GoogleMapsConfig()),
        MapCapability.disabled,
      );
      expect(
        await capability(const GoogleMapsConfig(enabled: true)),
        MapCapability.disabled,
      );
      expect(calls, 0);
    },
  );
  test('enabled without native key is unavailable', () async {
    expect(
      await capability(
        const GoogleMapsConfig(enabled: true, embeddedRiderMap: true),
      ),
      MapCapability.notConfigured,
    );
  });
  test('enabled with mock native setup is available', () async {
    nativeReady = true;
    expect(
      await capability(
        const GoogleMapsConfig(enabled: true, embeddedRiderMap: true),
      ),
      MapCapability.available,
    );
    expect(calls, 1);
  });
  test('native setup exception is isolated', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeMapConfiguration.channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    expect(
      await capability(
        const GoogleMapsConfig(enabled: true, embeddedRiderMap: true),
      ),
      MapCapability.initializationFailed,
    );
  });
  test('external navigation remains credential independent', () async {
    final uris = <Uri>[];
    final NavigationProvider navigation = ExternalNavigationProvider(
      android: true,
      launcher: (uri, _) async {
        uris.add(uri);
        return true;
      },
    );
    final result = await navigation.navigateTo(
      latitude: 28.61,
      longitude: 77.2,
      address: 'Pickup',
    );
    expect(result.opened, isTrue);
    expect(uris.single.scheme, 'google.navigation');
    expect(calls, 0);
  });
}
