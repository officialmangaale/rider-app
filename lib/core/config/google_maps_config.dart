class GoogleMapsConfig {
  const GoogleMapsConfig({
    this.enabled = false,
    this.embeddedRiderMap = false,
    this.routeOverlay = false,
    this.trafficEta = false,
  });

  static const environment = GoogleMapsConfig(
    enabled: bool.fromEnvironment('GOOGLE_MAPS_ENABLED'),
    embeddedRiderMap: bool.fromEnvironment('RIDER_EMBEDDED_MAP_ENABLED'),
    routeOverlay: bool.fromEnvironment('RIDER_ROUTE_OVERLAY_ENABLED'),
    trafficEta: bool.fromEnvironment('RIDER_TRAFFIC_ETA_ENABLED'),
  );

  final bool enabled;
  final bool embeddedRiderMap;
  final bool routeOverlay;
  final bool trafficEta;
  bool get requestsEmbeddedMap => enabled && embeddedRiderMap;
  bool get requestsRouteOverlay => requestsEmbeddedMap && routeOverlay;
  bool get requestsTrafficEta => requestsRouteOverlay && trafficEta;
}
