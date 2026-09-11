import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_models.dart';

class MapLaunchResult {
  const MapLaunchResult({
    required this.opened,
    this.targetUri,
    this.displayAddress,
  });

  final bool opened;
  final Uri? targetUri;
  final String? displayAddress;
}

abstract class MapLauncherService {
  Future<bool> openExternalRoute(DeliveryOrder order);

  Future<MapLaunchResult> openPoint({
    required double latitude,
    required double longitude,
    String? address,
  });

  /// Opens turn-by-turn navigation to a stop: Google Maps navigation on
  /// Android, falling back to the Maps website (which works with no Maps app
  /// installed). Free deep links only; no Maps SDK or API key.
  Future<MapLaunchResult> navigateTo({
    required double latitude,
    required double longitude,
    String? address,
  });
}

/// Whether [latitude]/[longitude] is a real position. 0,0 is what an unset
/// coordinate parses to, not a place anyone delivers to.
bool isUsableCoordinate(double latitude, double longitude) {
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 || longitude == 0);
}

/// Whether [address] names a place, rather than being empty or one of the
/// "... not available" fallbacks the models substitute.
bool isMeaningfulAddress(String? address) {
  final normalized = (address ?? '').trim().toLowerCase();
  return normalized.isNotEmpty && !normalized.contains('not available');
}

/// The links to try, in order, for navigating to a stop. Coordinates win over
/// the address; empty when there is nothing to navigate to.
List<Uri> navigationUris({
  required double latitude,
  required double longitude,
  String? address,
  required bool android,
}) {
  final String query;
  if (isUsableCoordinate(latitude, longitude)) {
    query = '$latitude,$longitude';
  } else if (isMeaningfulAddress(address)) {
    query = address!.trim().replaceAll(RegExp(r'\s+'), ' ');
  } else {
    return const <Uri>[];
  }
  return [
    // Uri.encodeComponent keeps an address with '&', '#' or spaces intact.
    if (android) Uri.parse('google.navigation:q=${Uri.encodeComponent(query)}'),
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
  ];
}

class UrlLauncherMapLauncherService implements MapLauncherService {
  UrlLauncherMapLauncherService({
    Future<bool> Function(Uri uri, LaunchMode mode)? launcher,
    bool? android,
  }) : _launcher = launcher ?? ((uri, mode) => launchUrl(uri, mode: mode)),
       _android = android ?? defaultTargetPlatform == TargetPlatform.android;

  final Future<bool> Function(Uri uri, LaunchMode mode) _launcher;
  final bool _android;

  @override
  Future<MapLaunchResult> navigateTo({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final uris = navigationUris(
      latitude: latitude,
      longitude: longitude,
      address: address,
      android: _android,
    );
    if (uris.isEmpty) {
      _debug('navigate skipped target=none');
      return MapLaunchResult(opened: false, displayAddress: address);
    }
    for (final uri in uris) {
      if (await _tryLaunch(uri, LaunchMode.externalApplication)) {
        _debug('navigate opened scheme=${uri.scheme}');
        return MapLaunchResult(
          opened: true,
          targetUri: uri,
          displayAddress: address,
        );
      }
    }
    // Last resort: the website in whatever the platform opens links with.
    final web = uris.last;
    final opened = await _tryLaunch(web, LaunchMode.platformDefault);
    _debug('navigate browser fallback result=$opened');
    return MapLaunchResult(
      opened: opened,
      targetUri: web,
      displayAddress: address,
    );
  }

  @override
  Future<bool> openExternalRoute(DeliveryOrder order) async {
    final result = await openPoint(
      latitude: order.deliveryLat,
      longitude: order.deliveryLng,
      address: order.dropAddress,
    );
    return result.opened;
  }

  @override
  Future<MapLaunchResult> openPoint({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final uri = _buildMapsUri(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    if (uri == null) {
      _debug('skipped target=none');
      return MapLaunchResult(opened: false, displayAddress: address);
    }

    final externalOpened = await _tryLaunch(
      uri,
      LaunchMode.externalApplication,
    );
    if (externalOpened) {
      _debug('opened mode=external');
      return MapLaunchResult(
        opened: true,
        targetUri: uri,
        displayAddress: address,
      );
    }

    final browserOpened = await _tryLaunch(uri, LaunchMode.platformDefault);
    _debug(
      'opened mode=browser result=$browserOpened target=${uri.host}${uri.path}',
    );
    return MapLaunchResult(
      opened: browserOpened,
      targetUri: uri,
      displayAddress: address,
    );
  }

  Uri? _buildMapsUri({
    required double latitude,
    required double longitude,
    String? address,
  }) {
    if (_isUsableCoordinate(latitude, longitude)) {
      return Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      });
    }

    final trimmedAddress = address?.trim();
    if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': trimmedAddress,
      });
    }

    return null;
  }

  Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await _launcher(uri, mode);
    } catch (_) {
      return false;
    }
  }

  bool _isUsableCoordinate(double latitude, double longitude) =>
      isUsableCoordinate(latitude, longitude);

  void _debug(String message) {
    assert(() {
      debugPrint('[MapLauncher] $message');
      return true;
    }());
  }
}
