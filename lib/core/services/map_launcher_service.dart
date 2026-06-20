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
}

class UrlLauncherMapLauncherService implements MapLauncherService {
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
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  bool _isUsableCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        latitude != 0 &&
        longitude != 0;
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[MapLauncher] $message');
      return true;
    }());
  }
}
