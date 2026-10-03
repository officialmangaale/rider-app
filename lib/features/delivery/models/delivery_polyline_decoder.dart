class DeliveryRoutePoint {
  const DeliveryRoutePoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

List<DeliveryRoutePoint> decodeGooglePolyline(String encoded) {
  final points = <DeliveryRoutePoint>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  while (index < encoded.length) {
    final latResult = _decodeValue(encoded, index);
    index = latResult.nextIndex;
    final lngResult = _decodeValue(encoded, index);
    index = lngResult.nextIndex;
    latitude += latResult.delta;
    longitude += lngResult.delta;
    points.add(DeliveryRoutePoint(latitude / 1e5, longitude / 1e5));
  }

  return points;
}

_PolylineValue _decodeValue(String encoded, int start) {
  var result = 0;
  var shift = 0;
  var index = start;
  while (index < encoded.length) {
    final byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
    if (byte < 0x20) {
      final delta = (result & 1) == 1 ? ~(result >> 1) : result >> 1;
      return _PolylineValue(delta, index);
    }
  }
  throw const FormatException('Invalid encoded polyline');
}

class _PolylineValue {
  const _PolylineValue(this.delta, this.nextIndex);

  final int delta;
  final int nextIndex;
}
