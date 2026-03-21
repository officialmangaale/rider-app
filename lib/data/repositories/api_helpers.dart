/// Shared helpers for safe API response parsing.
/// Extracted from the monolithic api_rider_repository.dart.
class ApiParseHelpers {
  const ApiParseHelpers._();

  /// Safely cast to Map, returning empty map on failure.
  static Map<String, dynamic> asMap(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  /// Safely cast to List, returning empty list on failure.
  static List<dynamic> asList(Object? value) {
    return value is List<dynamic> ? value : const <dynamic>[];
  }

  /// Safely extract an int from a dynamic value.
  static int asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely extract a double from a dynamic value.
  static double asDouble(Object? value, [double fallback = 0.0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely extract a string from a dynamic value.
  static String asString(Object? value, [String fallback = '']) {
    if (value is String) return value;
    if (value != null) return value.toString();
    return fallback;
  }

  /// Safely extract a boolean from a dynamic value.
  static bool asBool(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// Parse a DateTime from an ISO 8601 string, returns fallback on failure.
  static DateTime asDateTime(Object? value, [DateTime? fallback]) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    }
    return fallback ?? DateTime.now();
  }
}
