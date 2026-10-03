import '../../../core/network/api_client.dart';
import 'delivery_polyline_decoder.dart';

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

class DeliveryRouteModel {
  const DeliveryRouteModel({
    required this.encodedPolyline,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.staticDurationSeconds,
    this.trafficDelaySeconds,
    required this.provider,
    required this.destinationType,
    required this.generatedAt,
    required this.expiresAt,
  });

  final String encodedPolyline;
  final List<DeliveryRoutePoint> points;
  final int distanceMeters;
  final double durationSeconds;
  final double staticDurationSeconds;
  final double? trafficDelaySeconds;
  final String provider;
  final String destinationType;
  final DateTime generatedAt;
  final DateTime expiresAt;

  factory DeliveryRouteModel.fromJson(Map<String, dynamic> json) {
    final encoded = _asString(json['encoded_polyline']);
    return DeliveryRouteModel(
      encodedPolyline: encoded,
      points: decodeGooglePolyline(encoded),
      distanceMeters: _asInt(json['distance_meters']),
      durationSeconds: _asDouble(json['duration_seconds']),
      staticDurationSeconds: _asDouble(json['static_duration_seconds']),
      trafficDelaySeconds: json['traffic_delay_seconds'] == null
          ? null
          : _asDouble(json['traffic_delay_seconds']),
      provider: _asString(json['provider'], fallback: 'google'),
      destinationType: _asString(json['destination_type']),
      generatedAt: _asDateTime(json['generated_at']),
      expiresAt: _asDateTime(json['expires_at']),
    );
  }

  bool get hasDrawablePolyline => points.length >= 2;

  static Map<String, dynamic> extractRouteObject(Object? data) {
    final map = ApiClient.asMap(data);
    final route = ApiClient.asMap(map['route']);
    return route.isEmpty ? map : route;
  }
}
