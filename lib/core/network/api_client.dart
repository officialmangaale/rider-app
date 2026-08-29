import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/app_constants.dart';
import 'api_exception.dart';
import 'platform_http_client.dart';

abstract class ApiTokenStore {
  String? get accessToken;
  String? get refreshToken;
  Future<String> getDeviceId();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();
}

class ApiMeta {
  const ApiMeta({
    required this.raw,
    this.page,
    this.pageSize,
    this.total,
    this.count,
  });

  final Map<String, dynamic> raw;
  final int? page;
  final int? pageSize;
  final int? total;
  final int? count;

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      raw: json,
      page: _asInt(json['page']),
      pageSize: _asInt(json['page_size']),
      total: _asInt(json['total']),
      count: _asInt(json['count']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.success,
    required this.message,
    required this.data,
    this.meta,
    this.raw = const <String, dynamic>{},
    this.statusCode,
  });

  final bool success;
  final String message;
  final T data;
  final ApiMeta? meta;
  final Map<String, dynamic> raw;
  final int? statusCode;
}

typedef ApiParser<T> = T Function(dynamic data);

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.httpClient,
    required this.tokenStore,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 1,
    this.onUnauthorized,
  });

  final String baseUrl;
  final PlatformHttpClient httpClient;
  final ApiTokenStore tokenStore;
  final Duration timeout;
  final int maxRetries;
  final VoidCallback? onUnauthorized;

  Future<bool>? _refreshFuture;
  int _requestCounter = 0;

  Future<ApiEnvelope<Map<String, dynamic>>> getObject(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<Map<String, dynamic>>(
      'GET',
      path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => asMap(data),
    );
  }

  Future<ApiEnvelope<List<dynamic>>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<List<dynamic>>(
      'GET',
      path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => data is List<dynamic> ? data : const <dynamic>[],
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> postObject(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<Map<String, dynamic>>(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => asMap(data),
    );
  }

  Future<ApiEnvelope<List<dynamic>>> postList(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<List<dynamic>>(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => data is List<dynamic> ? data : const <dynamic>[],
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> putObject(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<Map<String, dynamic>>(
      'PUT',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => asMap(data),
    );
  }

  Future<ApiEnvelope<List<dynamic>>> putList(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<List<dynamic>>(
      'PUT',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => data is List<dynamic> ? data : const <dynamic>[],
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> patchObject(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<Map<String, dynamic>>(
      'PATCH',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => asMap(data),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> deleteObject(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request<Map<String, dynamic>>(
      'DELETE',
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: (data) => asMap(data),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> postMultipartFile(
    String path, {
    required File file,
    String fileField = 'file',
    bool requiresAuth = true,
    ValueChanged<double>? onProgress,
  }) async {
    final uri = _buildUri(path, null);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Accept'] = 'application/json';
    request.headers['X-Request-ID'] = _nextRequestId();

    if (requiresAuth) {
      final token = tokenStore.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    final ext = file.path.split('.').last.toLowerCase();
    MediaType? mediaType;
    if (ext == 'jpg' || ext == 'jpeg') {
      mediaType = MediaType('image', 'jpeg');
    } else if (ext == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (ext == 'pdf') {
      mediaType = MediaType('application', 'pdf');
    }

    final fileLength = await file.length();
    var sentBytes = 0;
    final fileStream = file.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sentBytes += chunk.length;
          if (fileLength > 0) {
            onProgress?.call((sentBytes / fileLength).clamp(0, 1));
          }
          sink.add(chunk);
        },
      ),
    );
    final filename = file.uri.pathSegments.isEmpty
        ? 'upload'
        : Uri.decodeComponent(file.uri.pathSegments.last);

    request.files.add(
      http.MultipartFile(
        fileField,
        http.ByteStream(fileStream),
        fileLength,
        filename: filename,
        contentType: mediaType,
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = _decodeBody(response.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{
              'success': false,
              'message': 'Unexpected response',
            };

      final success =
          payload['success'] as bool? ??
          _statusIndicatesSuccess(payload['status']) ??
          (response.statusCode >= 200 && response.statusCode < 300);

      if (!success || response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          message: payload['message'] as String? ?? 'Upload failed.',
          statusCode: response.statusCode,
          errorCode: payload['error_code'] as String?,
          errors: asMap(payload['errors']),
          rawData: payload,
        );
      }

      onProgress?.call(1);

      return ApiEnvelope<Map<String, dynamic>>(
        success: true,
        message: payload['message'] as String? ?? '',
        data: asMap(payload['data']),
        meta: payload['meta'] is Map<String, dynamic>
            ? ApiMeta.fromJson(payload['meta'] as Map<String, dynamic>)
            : null,
        raw: payload,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ApiException(
        message: 'Upload timed out. Please check your connection.',
        statusCode: 0,
      );
    } on SocketException catch (error) {
      throw ApiException(
        message: 'Network error. Please check your connection and try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    } on HandshakeException catch (error) {
      throw ApiException(
        message: 'Secure connection failed. Please try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    } on IOException catch (error) {
      throw ApiException(
        message: 'Network error. Please check your connection and try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        message: 'Network error. Please check your connection and try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    }
  }

  Future<ApiEnvelope<T>> request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    required ApiParser<T> parser,
  }) {
    return _requestWithRetry<T>(
      method,
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: parser,
      hasRetried: false,
      retryCount: 0,
    );
  }

  Future<ApiEnvelope<T>> _requestWithRetry<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required bool requiresAuth,
    required ApiParser<T> parser,
    required bool hasRetried,
    required int retryCount,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Request-ID': _nextRequestId(),
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    final requestToken = requiresAuth ? tokenStore.accessToken : null;
    final hasAuthorizationHeader =
        requestToken != null && requestToken.isNotEmpty;
    if (hasAuthorizationHeader) {
      headers['Authorization'] = 'Bearer $requestToken';
    }

    RawHttpResponse raw;

    try {
      _debugLogRequest(method, uri, body);
      raw = await httpClient
          .send(
            method,
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      if (retryCount < maxRetries) {
        return _requestWithRetry<T>(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          parser: parser,
          hasRetried: hasRetried,
          retryCount: retryCount + 1,
        );
      }
      throw const ApiException(
        message: 'Request timed out. Please check your connection.',
        statusCode: 0,
        errorCode: 'REQUEST_TIMEOUT',
      );
    } on SocketException catch (error) {
      throw ApiException(
        message: 'Network error. Please check your connection and try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    } on HandshakeException catch (error) {
      throw ApiException(
        message: 'Secure connection failed. Please try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    } on IOException catch (error) {
      throw ApiException(
        message: 'Network error. Please check your connection and try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        message: 'Network error. Please check your connection and try again.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
        rawData: error.toString(),
      );
    }

    final decoded = _decodeBody(raw.body);

    // Handle 401 with token refresh (single attempt).
    if (requiresAuth &&
        hasAuthorizationHeader &&
        raw.statusCode == 401 &&
        !hasRetried) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return _requestWithRetry<T>(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          parser: parser,
          hasRetried: true,
          retryCount: retryCount,
        );
      } else {
        onUnauthorized?.call();
      }
    } else if (requiresAuth && raw.statusCode == 401) {
      onUnauthorized?.call();
    }

    // Retry on 5xx server errors (up to maxRetries).
    if (raw.statusCode >= 500 && retryCount < maxRetries) {
      await Future<void>.delayed(
        Duration(milliseconds: 500 * (retryCount + 1)),
      );
      return _requestWithRetry<T>(
        method,
        path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        parser: parser,
        hasRetried: hasRetried,
        retryCount: retryCount + 1,
      );
    }

    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'success': false, 'message': 'Unexpected response'};
    _debugLogResponse(method, uri, raw.statusCode, payload);
    final success =
        payload['success'] as bool? ??
        _statusIndicatesSuccess(payload['status']) ??
        (raw.statusCode >= 200 && raw.statusCode < 300);

    if (!success || raw.statusCode < 200 || raw.statusCode >= 300) {
      throw ApiException(
        message: _extractReadableMessage(payload, fallback: 'Request failed.'),
        statusCode: raw.statusCode,
        errorCode: _asString(payload['error_code']),
        errors: asMap(payload['errors']),
        rawData: payload,
      );
    }

    final parsedData = _parseEnvelopeData<T>(
      parser,
      payload['data'],
      statusCode: raw.statusCode,
      payload: payload,
    );

    return ApiEnvelope<T>(
      success: true,
      message: _asString(payload['message']) ?? '',
      data: parsedData,
      meta: payload['meta'] is Map<String, dynamic>
          ? ApiMeta.fromJson(payload['meta'] as Map<String, dynamic>)
          : null,
      raw: payload,
      statusCode: raw.statusCode,
    );
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final nextQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        nextQuery[key] = '$value';
      }
    });
    return uri.replace(queryParameters: nextQuery);
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{'success': false, 'message': body};
    }
  }

  T _parseEnvelopeData<T>(
    ApiParser<T> parser,
    Object? data, {
    required int statusCode,
    required Map<String, dynamic> payload,
  }) {
    try {
      return parser(data);
    } catch (error) {
      assert(() {
        debugPrint('API response parse failed status=$statusCode error=$error');
        return true;
      }());
      throw ApiException(
        message: 'We could not read the server response. Please try again.',
        statusCode: statusCode,
        errorCode: 'MALFORMED_RESPONSE',
        rawData: payload,
      );
    }
  }

  String _extractReadableMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final directMessage =
        _asString(payload['message']) ??
        _asString(payload['error']) ??
        _asString(payload['detail']);
    final validationMessage = _firstValidationMessage(asMap(payload['errors']));
    if (directMessage != null && validationMessage != null) {
      return '$directMessage: $validationMessage';
    }
    return directMessage ?? validationMessage ?? fallback;
  }

  String? _firstValidationMessage(Map<String, dynamic> errors) {
    for (final entry in errors.entries) {
      final value = entry.value;
      if (value is String && value.trim().isNotEmpty) {
        return '${entry.key}: ${value.trim()}';
      }
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) {
          return '${entry.key}: ${first.trim()}';
        }
      }
    }
    return null;
  }

  String? _asString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  bool? _statusIndicatesSuccess(Object? value) {
    final status = _asString(value)?.toLowerCase();
    if (status == null) {
      return null;
    }
    if (status == 'success' || status == 'ok') {
      return true;
    }
    if (status == 'error' || status == 'failed' || status == 'failure') {
      return false;
    }
    return null;
  }

  void _debugLogRequest(String method, Uri uri, Object? body) {
    assert(() {
      if (_isAuthUri(uri)) {
        debugPrint(
          'API request $method $uri bodyKeys=${_bodyKeys(body).join(',')}',
        );
      }
      return true;
    }());
  }

  void _debugLogResponse(
    String method,
    Uri uri,
    int statusCode,
    Map<String, dynamic> payload,
  ) {
    assert(() {
      if (_isAuthUri(uri)) {
        debugPrint(
          'API response $method $uri status=$statusCode keys=${payload.keys.join(',')}',
        );
      }
      return true;
    }());
  }

  bool _isAuthUri(Uri uri) {
    return uri.path.contains('/auth/') || uri.path.endsWith('/users/login');
  }

  List<String> _bodyKeys(Object? body) {
    if (body is Map) {
      return body.keys.map((key) => '$key').toList(growable: false);
    }
    return const <String>[];
  }

  Future<bool> _refreshTokens() {
    final ongoing = _refreshFuture;
    if (ongoing != null) {
      return ongoing;
    }

    final future = _performRefresh();
    _refreshFuture = future;
    return future.whenComplete(() => _refreshFuture = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = tokenStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await tokenStore.clearTokens();
      return false;
    }

    try {
      final raw = await httpClient
          .send(
            'POST',
            _buildUri('/auth/refresh-token', null),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'refresh_token': refreshToken,
              'device_id': await tokenStore.getDeviceId(),
            }),
          )
          .timeout(timeout);

      final decoded = _decodeBody(raw.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{
              'success': false,
              'message': 'Token refresh failed',
            };
      if ((payload['success'] as bool? ?? false) != true) {
        await tokenStore.clearTokens();
        return false;
      }

      final data = asMap(payload['data']);
      final nextAccessToken = data['access_token'] as String?;
      final nextRefreshToken = data['refresh_token'] as String? ?? refreshToken;
      if (nextAccessToken == null || nextAccessToken.isEmpty) {
        await tokenStore.clearTokens();
        return false;
      }

      await tokenStore.saveTokens(
        accessToken: nextAccessToken,
        refreshToken: nextRefreshToken,
      );
      return true;
    } catch (_) {
      await tokenStore.clearTokens();
      return false;
    }
  }

  String _nextRequestId() {
    _requestCounter += 1;
    return '${AppConstants.requestIdPrefix}-${DateTime.now().millisecondsSinceEpoch}-$_requestCounter';
  }

  /// Public helper so repositories can use it for safe parsing.
  static Map<String, dynamic> asMap(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }
}
