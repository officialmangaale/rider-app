import 'dart:convert';

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
  });

  final bool success;
  final String message;
  final T data;
  final ApiMeta? meta;
  final Map<String, dynamic> raw;
}

typedef ApiParser<T> = T Function(dynamic data);

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.httpClient,
    required this.tokenStore,
  });

  final String baseUrl;
  final PlatformHttpClient httpClient;
  final ApiTokenStore tokenStore;

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
      parser: (data) => _asMap(data),
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
      parser: (data) => _asMap(data),
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
      parser: (data) => _asMap(data),
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
      parser: (data) => _asMap(data),
    );
  }

  Future<ApiEnvelope<T>> request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    required ApiParser<T> parser,
  }) {
    return _request<T>(
      method,
      path,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      parser: parser,
      hasRetried: false,
    );
  }

  Future<ApiEnvelope<T>> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required bool requiresAuth,
    required ApiParser<T> parser,
    required bool hasRetried,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Request-ID': _nextRequestId(),
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (requiresAuth) {
      final token = tokenStore.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final raw = await httpClient.send(
      method,
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    final decoded = _decodeBody(raw.body);

    if (requiresAuth && raw.statusCode == 401 && !hasRetried) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return _request<T>(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          parser: parser,
          hasRetried: true,
        );
      }
    }

    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'success': false, 'message': 'Unexpected response'};
    final success = payload['success'] as bool? ??
        (raw.statusCode >= 200 && raw.statusCode < 300);

    if (!success || raw.statusCode < 200 || raw.statusCode >= 300) {
      throw ApiException(
        message: payload['message'] as String? ?? 'Request failed.',
        statusCode: raw.statusCode,
        errorCode: payload['error_code'] as String?,
        errors: _asMap(payload['errors']),
        rawData: payload,
      );
    }

    return ApiEnvelope<T>(
      success: true,
      message: payload['message'] as String? ?? '',
      data: parser(payload['data']),
      meta: payload['meta'] is Map<String, dynamic>
          ? ApiMeta.fromJson(payload['meta'] as Map<String, dynamic>)
          : null,
      raw: payload,
    );
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse('$baseUrl$path');
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
      final raw = await httpClient.send(
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
      );

      final decoded = _decodeBody(raw.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'success': false, 'message': 'Token refresh failed'};
      if ((payload['success'] as bool? ?? false) != true) {
        await tokenStore.clearTokens();
        return false;
      }

      final data = _asMap(payload['data']);
      final nextAccessToken = data['access_token'] as String?;
      final nextRefreshToken =
          data['refresh_token'] as String? ?? refreshToken;
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

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }
}
