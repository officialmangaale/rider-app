import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only controls implemented in MainActivity.kt: the optional
/// floating rider bubble and the battery-optimisation shortcut.
///
/// Every call degrades to a safe no-op off Android or if the native side is
/// missing, so the rest of Online mode never depends on it.
abstract class RiderPlatform {
  Future<bool> canDrawOverlays();
  Future<void> openOverlaySettings();
  Future<void> showBubble();
  Future<void> hideBubble();
  Future<bool> isIgnoringBatteryOptimizations();
  Future<void> openBatteryOptimizationSettings();
}

class MethodChannelRiderPlatform implements RiderPlatform {
  static const _channel = MethodChannel('com.mangaale.rider/platform');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> canDrawOverlays() => _bool('canDrawOverlays');

  @override
  Future<void> openOverlaySettings() => _call('openOverlaySettings');

  @override
  Future<void> showBubble() => _call('showBubble');

  @override
  Future<void> hideBubble() => _call('hideBubble');

  @override
  Future<bool> isIgnoringBatteryOptimizations() =>
      _bool('isIgnoringBatteryOptimizations');

  @override
  Future<void> openBatteryOptimizationSettings() =>
      _call('openBatteryOptimizationSettings');

  Future<bool> _bool(String method) async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (error) {
      _debug('$method failed code=${error.code}');
      return false;
    } on MissingPluginException {
      _debug('$method unavailable');
      return false;
    }
  }

  Future<void> _call(String method) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      _debug('$method failed code=${error.code}');
    } on MissingPluginException {
      _debug('$method unavailable');
    }
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[RiderPlatform] $message');
      return true;
    }());
  }
}
