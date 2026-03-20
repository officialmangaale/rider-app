class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.errors = const <String, dynamic>{},
    this.rawData,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic> errors;
  final Object? rawData;

  bool get isUnauthorized => statusCode == 401 || errorCode == 'UNAUTHORIZED';
  bool get isValidationError => errorCode == 'VALIDATION_FAILED';

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, errorCode: $errorCode, message: $message)';
  }
}
