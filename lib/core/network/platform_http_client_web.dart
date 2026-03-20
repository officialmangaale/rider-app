import 'dart:async';
import 'dart:html' as html;

import 'platform_http_client_base.dart';

PlatformHttpClient createPlatformHttpClient() => _WebPlatformHttpClient();

class _WebPlatformHttpClient implements PlatformHttpClient {
  @override
  Future<RawHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    final request = await html.HttpRequest.request(
      uri.toString(),
      method: method,
      sendData: body,
      requestHeaders: headers,
      timeout: 30000,
    ).timeout(const Duration(seconds: 30));

    final rawHeaders = request.getAllResponseHeaders() ?? '';
    final parsedHeaders = <String, String>{};
    for (final line in rawHeaders.split('\n')) {
      final separatorIndex = line.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }
      final key = line.substring(0, separatorIndex).trim();
      final value = line.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        parsedHeaders[key] = value;
      }
    }

    return RawHttpResponse(
      statusCode: request.status ?? 0,
      body: request.responseText ?? '',
      headers: parsedHeaders,
    );
  }
}
