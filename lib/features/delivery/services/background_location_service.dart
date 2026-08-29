import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _notificationChannelId = 'rider_location_channel';
const int _notificationId = 888;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _notificationChannelId,
    'Active Delivery Tracking',
    description: 'Tracks your location while you are on an active delivery.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _notificationChannelId,
      initialNotificationTitle: 'Rydex Rider',
      initialNotificationContent: 'Location tracking is ready',
      foregroundServiceNotificationId: _notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? positionStream;

  service.on('stopService').listen((event) {
    positionStream?.cancel();
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    final token = prefs.getString('auth_token') ?? '';
    final baseUrl = prefs.getString('api_base_url') ?? 'http://10.0.2.2:8000';

    if (token.isEmpty) {
      debugPrint('[BackgroundLocation] No auth token found.');
      return;
    }

    flutterLocalNotificationsPlugin.show(
      id: _notificationId,
      title: 'Active Delivery',
      body: 'Tracking your location...',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          'Active Delivery Tracking',
          icon: 'ic_bg_service_small',
          ongoing: true,
        ),
      ),
    );

    positionStream?.cancel();
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      ),
    ).listen((Position position) async {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/riders/location');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'heading': position.heading,
            'speed': position.speed,
          }),
        );
        debugPrint(
            '[BackgroundLocation] Synced ${position.latitude}, ${position.longitude} -> ${response.statusCode}');
      } catch (e) {
        debugPrint('[BackgroundLocation] Sync failed: $e');
      }
    });
  });
}
