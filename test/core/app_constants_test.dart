import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/core/constants/app_constants.dart';

// A normal build (no --dart-define) must keep talking to production exactly as
// before; the overrides exist only so a test build can target another server.
void main() {
  test('default server origins are production', () {
    expect(AppConstants.apiBaseUrl, 'https://rider-prod.mangaale.com');
    expect(AppConstants.riderWsUrl, 'wss://rider-prod.mangaale.com/ws/rider');
    expect(AppConstants.userApiBaseUrl, 'https://user-prod.mangaale.com');
    expect(
      AppConstants.restaurantApiBaseUrl,
      'https://restaurant-prod.mangaale.com',
    );
  });
}
