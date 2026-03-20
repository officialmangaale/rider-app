import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'platform_http_client_base.dart';

PlatformHttpClient createPlatformHttpClient() => _IoPlatformHttpClient();

class _IoPlatformHttpClient implements PlatformHttpClient {
  _IoPlatformHttpClient() : _client = HttpClient();

  final HttpClient _client;

  @override
  Future<RawHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    final request = await _client.openUrl(method, uri).timeout(
      const Duration(seconds: 30),
    );

    headers.forEach(request.headers.set);
    if (body != null && body.isNotEmpty) {
      request.add(utf8.encode(body));
    }

    final response = await request.close().timeout(const Duration(seconds: 30));
    final responseBody = await response.transform(utf8.decoder).join();

    final flattenedHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      flattenedHeaders[name] = values.join(',');
    });

    return RawHttpResponse(
      statusCode: response.statusCode,
      body: responseBody,
      headers: flattenedHeaders,
    );
  }
}
