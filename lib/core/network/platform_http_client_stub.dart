import 'platform_http_client_base.dart';

PlatformHttpClient createPlatformHttpClient() => _UnsupportedPlatformHttpClient();

class _UnsupportedPlatformHttpClient implements PlatformHttpClient {
  @override
  Future<RawHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) {
    throw UnsupportedError('No HTTP client is available on this platform.');
  }
}
