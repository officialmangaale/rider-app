import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/maps/map_capabilities.dart';
import '../../../presentation/providers/core_providers.dart';
import '../models/delivery_map_data.dart';
import '../models/delivery_models.dart';
import '../models/delivery_route.dart';
import '../providers/delivery_route_provider.dart';
import '../providers/rider_delivery_provider.dart';
import 'delivery_map_camera.dart';

class EmbeddedDeliveryMapScreen extends ConsumerWidget {
  const EmbeddedDeliveryMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderDeliveryControllerProvider);
    final order = state.activeOrder;
    final capability = ref.watch(mapCapabilityProvider);
    final mapsConfig = ref.watch(googleMapsConfigProvider);
    final routeState = ref.watch(deliveryRouteControllerProvider);
    final locationService = ref.read(riderLocationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Delivery map' : 'Order ${order.orderId}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: order == null || isTerminalDeliveryMapPhase(order)
                ? const Center(child: Text('No active delivery'))
                : capability.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _MapFallback(
                      title: 'Map unavailable',
                      message: 'Open Google Maps to continue navigation.',
                      onRetry: () => ref.invalidate(mapCapabilityProvider),
                    ),
                    data: (value) => value == MapCapability.available
                        ? ValueListenableBuilder<Position?>(
                            valueListenable: locationService.positionListenable,
                            builder: (context, position, _) {
                              final effectivePosition =
                                  position ?? locationService.lastPosition;
                              final phase = deliveryMapPhaseFor(order);
                              final markers = deliveryMapMarkers(
                                order,
                                effectivePosition,
                              );
                              final focus = deliveryMapFocusMarkers(
                                markers,
                                phase,
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted) return;
                                unawaited(
                                  ref
                                      .read(
                                        deliveryRouteControllerProvider
                                            .notifier,
                                      )
                                      .sync(
                                        order: order,
                                        position: effectivePosition,
                                        enabled:
                                            mapsConfig.requestsRouteOverlay,
                                      ),
                                );
                              });
                              final routeKey = deliveryRouteKeyFor(order);
                              final route = routeState.activeKey == routeKey
                                  ? routeState.route
                                  : null;
                              return EmbeddedDeliveryMap(
                                key: ValueKey(order.orderId),
                                markers: markers,
                                focusMarkers: focus,
                                route: route,
                                mapContext:
                                    '${order.orderId}:${phase.name}:${order.deliveryStatus}',
                                phaseLabel: deliveryMapPhaseLabel(order),
                                routeMessage: _routeMessage(
                                  route,
                                  routeState,
                                  mapsConfig.requestsTrafficEta,
                                ),
                                locationMessage:
                                    state.locationPermissionGranted &&
                                        state.locationServiceEnabled &&
                                        effectivePosition != null
                                    ? null
                                    : state.locationMessage,
                                locationActions: _locationActions(
                                  context,
                                  ref,
                                  state,
                                ),
                              );
                            },
                          )
                        : _MapFallback(
                            title: value == MapCapability.disabled
                                ? 'Map disabled'
                                : 'Map unavailable',
                            message:
                                'Embedded Maps is not ready. External navigation is still available.',
                            onRetry: value == MapCapability.disabled
                                ? null
                                : () => ref.invalidate(mapCapabilityProvider),
                          ),
                  ),
          ),
          if (order != null)
            SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Open Google Maps'),
                  onPressed: () => _navigate(context, ref, order),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _locationActions(
    BuildContext context,
    WidgetRef ref,
    RiderDeliveryState state,
  ) {
    if (state.canRequestLocationPermission) {
      return [
        TextButton(
          onPressed: state.locationActionInProgress
              ? null
              : () => ref
                    .read(riderDeliveryControllerProvider.notifier)
                    .bootstrapSessionLocation(requestPermission: true),
          child: const Text('Allow location'),
        ),
      ];
    }
    final service = ref.read(riderLocationServiceProvider);
    if (state.canOpenAppSettings) {
      return [
        TextButton(
          onPressed: service.openAppSettings,
          child: const Text('Open app settings'),
        ),
      ];
    }
    if (state.canOpenLocationSettings) {
      return [
        TextButton(
          onPressed: service.openLocationSettings,
          child: const Text('Open location settings'),
        ),
      ];
    }
    return const [];
  }

  Future<void> _navigate(
    BuildContext context,
    WidgetRef ref,
    ActiveDeliveryOrderModel order,
  ) async {
    final pickup = deliveryMapPhaseFor(order) == DeliveryMapPhase.pickup;
    final result = await ref
        .read(mapLauncherServiceProvider)
        .navigateTo(
          latitude: pickup ? order.pickupLatitude : order.dropLatitude,
          longitude: pickup ? order.pickupLongitude : order.dropLongitude,
          address: pickup ? order.pickupAddress : order.dropAddress,
        );
    _debugRiderMap('external_navigation_used opened=${result.opened}');
    if (!result.opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps')),
      );
    }
  }
}

typedef DeliveryMapBuilder =
    Widget Function(List<DeliveryMapMarker> markers, VoidCallback onReady);

enum _CameraMode { autoFrame, followRider, manual }

/// Stable native map instance. The widget reads already-owned delivery/GPS
/// state and performs visual-only rider interpolation; it never starts GPS or
/// sends backend location updates.
class EmbeddedDeliveryMap extends StatefulWidget {
  const EmbeddedDeliveryMap({
    required this.markers,
    List<DeliveryMapMarker>? focusMarkers,
    this.route,
    this.locationMessage,
    this.locationActions = const [],
    this.phaseLabel,
    this.routeMessage,
    this.mapContext = '',
    this.mapBuilder,
    super.key,
  }) : focusMarkers = focusMarkers ?? markers;

  final List<DeliveryMapMarker> markers;
  final List<DeliveryMapMarker> focusMarkers;
  final DeliveryRouteModel? route;
  final String? locationMessage;
  final List<Widget> locationActions;
  final String? phaseLabel;
  final String? routeMessage;
  final String mapContext;
  final DeliveryMapBuilder? mapBuilder;

  @override
  State<EmbeddedDeliveryMap> createState() => _EmbeddedDeliveryMapState();
}

class _EmbeddedDeliveryMapState extends State<EmbeddedDeliveryMap>
    with SingleTickerProviderStateMixin {
  static const _interpolationDuration = Duration(milliseconds: 650);
  static const _largeJumpMeters = 1000.0;
  static const _followCameraInterval = Duration(milliseconds: 900);

  GoogleMapController? _controller;
  Timer? _initializationTimer;
  late final AnimationController _riderAnimation;
  List<DeliveryMapMarker> _displayMarkers = const [];
  DeliveryMapMarker? _riderStart;
  DeliveryMapMarker? _riderEnd;
  bool _ready = false;
  bool _failed = false;
  bool _cameraAnimating = false;
  _CameraMode _cameraMode = _CameraMode.autoFrame;
  DateTime? _lastFollowCameraAt;
  String? _lastMapContext;

  @override
  void initState() {
    super.initState();
    _displayMarkers = widget.markers;
    _lastMapContext = widget.mapContext;
    _riderAnimation = AnimationController(
      vsync: this,
      duration: _interpolationDuration,
    )..addListener(_applyRiderAnimation);
    if (widget.markers.isNotEmpty) _startDeadline();
  }

  @override
  void didUpdateWidget(covariant EmbeddedDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mapContext != _lastMapContext) {
      _lastMapContext = widget.mapContext;
      _cameraMode = _CameraMode.autoFrame;
      _riderAnimation.stop();
      _displayMarkers = widget.markers;
      if (_ready) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_fitDelivery());
        });
      }
      return;
    }

    _updateDisplayedMarkers(widget.markers);
    if (!_ready &&
        !_failed &&
        _initializationTimer == null &&
        widget.markers.isNotEmpty) {
      _startDeadline();
    }
    if (_ready && _cameraMode == _CameraMode.followRider) {
      final rider = _markerFor(widget.markers, DeliveryMapStop.rider);
      if (rider != null) unawaited(_followRider(rider));
    }
  }

  void _startDeadline() {
    _initializationTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _ready) return;
      _debugRiderMap('initialization_failed timeout=true');
      setState(() => _failed = true);
    });
  }

  void _onReady() {
    if (!mounted || _failed) return;
    _initializationTimer?.cancel();
    _debugRiderMap('initialized');
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_fitDelivery());
    });
  }

  void _updateDisplayedMarkers(List<DeliveryMapMarker> nextMarkers) {
    final previousRider = _markerFor(_displayMarkers, DeliveryMapStop.rider);
    final nextRider = _markerFor(nextMarkers, DeliveryMapStop.rider);
    if (previousRider == null ||
        nextRider == null ||
        _distanceMeters(previousRider, nextRider) > _largeJumpMeters) {
      _riderAnimation.stop();
      setState(() => _displayMarkers = nextMarkers);
      return;
    }
    if (previousRider.latitude == nextRider.latitude &&
        previousRider.longitude == nextRider.longitude &&
        previousRider.heading == nextRider.heading) {
      setState(() => _displayMarkers = nextMarkers);
      return;
    }
    _riderStart = previousRider;
    _riderEnd = nextRider;
    _displayMarkers = _mergeRider(nextMarkers, previousRider);
    _riderAnimation.forward(from: 0);
  }

  void _applyRiderAnimation() {
    final start = _riderStart;
    final end = _riderEnd;
    if (!mounted || start == null || end == null) return;
    final t = Curves.easeOut.transform(_riderAnimation.value);
    final interpolated = end.copyWith(
      latitude: _lerp(start.latitude, end.latitude, t),
      longitude: _lerp(start.longitude, end.longitude, t),
      heading: end.heading ?? start.heading,
    );
    setState(() {
      _displayMarkers = _mergeRider(widget.markers, interpolated);
    });
  }

  Future<void> _fitDelivery() async {
    final points = widget.focusMarkers.isEmpty
        ? _displayMarkers
        : widget.focusMarkers;
    await _animateToBounds(points);
  }

  Future<void> _followRider(DeliveryMapMarker rider) async {
    final last = _lastFollowCameraAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _followCameraInterval) return;
    _lastFollowCameraAt = now;
    final controller = _controller;
    if (controller == null) return;
    await _animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(rider.latitude, rider.longitude), 16),
    );
  }

  Future<void> _recenter() async {
    final rider = _markerFor(_displayMarkers, DeliveryMapStop.rider);
    if (rider == null) {
      _cameraMode = _CameraMode.autoFrame;
      await _fitDelivery();
      return;
    }
    _cameraMode = _CameraMode.followRider;
    await _followRider(rider);
  }

  Future<void> _animateToBounds(List<DeliveryMapMarker> markers) async {
    final controller = _controller;
    final bounds = deliveryCameraBoundsFor(markers);
    if (controller == null || bounds == null) return;
    try {
      if (markers.length == 1) {
        await _animateCamera(CameraUpdate.newLatLngZoom(bounds.center, 15));
      } else {
        await _animateCamera(
          CameraUpdate.newLatLngBounds(bounds.toLatLngBounds(), 56),
        );
      }
    } catch (_) {
      // A layout race should not remove otherwise usable markers.
    }
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final controller = _controller;
    if (controller == null) return;
    _cameraAnimating = true;
    try {
      await controller.animateCamera(update);
    } finally {
      _cameraAnimating = false;
    }
  }

  void _onUserCameraGesture() {
    if (_cameraAnimating || _cameraMode == _CameraMode.manual) return;
    setState(() => _cameraMode = _CameraMode.manual);
  }

  @override
  void dispose() {
    _initializationTimer?.cancel();
    _riderAnimation.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _MapFallback(
        title: 'Map could not load',
        message: 'Check your connection or open Google Maps.',
        onRetry: () {
          setState(() {
            _failed = false;
            _ready = false;
          });
          if (widget.markers.isNotEmpty) _startDeadline();
        },
      );
    }
    if (widget.markers.isEmpty) {
      return _MapFallback(
        title: widget.locationMessage ?? 'Location unavailable',
        message: 'Open Google Maps to keep moving while location catches up.',
        actions: widget.locationActions,
      );
    }
    final first = widget.focusMarkers.isNotEmpty
        ? widget.focusMarkers.first
        : widget.markers.first;
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (_) => _onUserCameraGesture(),
          child:
              widget.mapBuilder?.call(_displayMarkers, _onReady) ??
              GoogleMap(
                key: const ValueKey('delivery-google-map'),
                initialCameraPosition: CameraPosition(
                  target: LatLng(first.latitude, first.longitude),
                  zoom: 14,
                ),
                markers: googleDeliveryMarkers(_displayMarkers),
                polylines: googleDeliveryPolylines(widget.route),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                onCameraMoveStarted: _onUserCameraGesture,
                onMapCreated: (controller) {
                  if (!mounted || _failed) {
                    controller.dispose();
                    return;
                  }
                  _controller = controller;
                  _onReady();
                },
              ),
        ),
        if (!_ready)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        if (widget.phaseLabel != null ||
            widget.routeMessage != null ||
            widget.locationMessage != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.phaseLabel != null)
                      Text(
                        widget.phaseLabel!,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    if (widget.routeMessage != null) ...[
                      if (widget.phaseLabel != null) const SizedBox(height: 4),
                      Text(widget.routeMessage!),
                    ],
                    if (widget.locationMessage != null) ...[
                      if (widget.phaseLabel != null ||
                          widget.routeMessage != null)
                        const SizedBox(height: 4),
                      Text(widget.locationMessage!),
                      if (widget.locationActions.isNotEmpty)
                        Wrap(spacing: 8, children: widget.locationActions),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Material(
            shape: const CircleBorder(),
            color: Theme.of(context).colorScheme.surface,
            elevation: 2,
            child: IconButton(
              tooltip: _cameraMode == _CameraMode.followRider
                  ? 'Following rider'
                  : 'Follow rider',
              onPressed: _ready ? _recenter : null,
              icon: Icon(
                _cameraMode == _CameraMode.followRider
                    ? Icons.my_location
                    : Icons.near_me_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Set<Marker> googleDeliveryMarkers(List<DeliveryMapMarker> markers) => {
  for (final marker in markers)
    Marker(
      markerId: MarkerId(marker.stop.name),
      position: LatLng(marker.latitude, marker.longitude),
      rotation: marker.stop == DeliveryMapStop.rider
          ? (marker.heading ?? 0)
          : 0,
      flat: marker.stop == DeliveryMapStop.rider && marker.heading != null,
      infoWindow: InfoWindow(title: marker.label),
      icon: BitmapDescriptor.defaultMarkerWithHue(switch (marker.stop) {
        DeliveryMapStop.rider => BitmapDescriptor.hueAzure,
        DeliveryMapStop.pickup => BitmapDescriptor.hueOrange,
        DeliveryMapStop.drop => BitmapDescriptor.hueRed,
      }),
    ),
};

Set<Polyline> googleDeliveryPolylines(DeliveryRouteModel? route) {
  if (route == null || !route.hasDrawablePolyline) return const {};
  return {
    Polyline(
      polylineId: const PolylineId('delivery_route'),
      points: [
        for (final point in route.points)
          LatLng(point.latitude, point.longitude),
      ],
      color: const Color(0xFF1565C0),
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    ),
  };
}

String? _routeMessage(
  DeliveryRouteModel? route,
  DeliveryRouteState state,
  bool showTrafficEta,
) {
  if (route != null) {
    final distance = _formatRouteDistance(route.distanceMeters);
    final duration = _formatRouteDuration(route.durationSeconds);
    if (showTrafficEta && route.trafficDelaySeconds != null) {
      final delay = _formatRouteDuration(route.trafficDelaySeconds!);
      return '$distance • $duration ETA • +$delay traffic';
    }
    return '$distance • $duration ETA';
  }
  if (state.status == DeliveryRouteStatus.loading) {
    return 'Loading route...';
  }
  if (state.status == DeliveryRouteStatus.unavailable) {
    return 'Route unavailable';
  }
  return null;
}

String _formatRouteDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
}

String _formatRouteDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({
    required this.title,
    required this.message,
    this.onRetry,
    this.actions = const [],
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null || actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ...actions,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

DeliveryMapMarker? _markerFor(
  List<DeliveryMapMarker> markers,
  DeliveryMapStop stop,
) {
  for (final marker in markers) {
    if (marker.stop == stop) return marker;
  }
  return null;
}

List<DeliveryMapMarker> _mergeRider(
  List<DeliveryMapMarker> markers,
  DeliveryMapMarker rider,
) {
  return [
    for (final marker in markers)
      marker.stop == DeliveryMapStop.rider ? rider : marker,
  ];
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _distanceMeters(DeliveryMapMarker a, DeliveryMapMarker b) {
  const earth = 6371000.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLng = _radians(b.longitude - a.longitude);
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final hav =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earth * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
}

double _radians(double value) => value * math.pi / 180;

void _debugRiderMap(String message) {
  assert(() {
    debugPrint('[RiderMap] $message');
    return true;
  }());
}
