# Rider background mode — investigation (before this change)

Date: 2026-09-11. Read-only review of rider-app, rider-service and the
rider-prod proxy. Line references are to the code as it was before this change.

## Summary

An Online rider stopped sharing location the moment the app left the screen,
so dispatch, which ignores riders whose last fix is older than 5 minutes,
treated them as absent. A background service existed but could never have
worked. Delivery requests reached a backgrounded app only as a one-shot sound
if the process happened to be alive. There was no request notification
channel, no push, and no floating shortcut.

## Current behaviour, with evidence

| Area | What the code did | Where |
|---|---|---|
| Online state | Server-side: `rider_availability.is_online/is_available`, set by `POST /api/v1/rider/go-online` / `go-offline`. The app reads it at launch (`GET /api/v1/rider/availability`) into `RiderDeliveryState.isOnline`. | `rider_delivery_provider.dart` `bootstrapSessionLocation`, `toggleOnline`; rider-service `RiderService.GoOffline` |
| Location tracking | `RiderLocationService`: geolocator stream (distance filter 35 m idle / 15 m active) plus a poll every 30 s / 20 s. | `services/rider_location_service.dart` `startTracking` |
| Upload interval | Throttled in the controller: at most every 30 s idle / 15 s active, and a stationary rider only every 2 min. `POST /api/v1/location/update`. | `rider_delivery_provider.dart` `_shouldSendPosition` |
| App lifecycle | `inactive`, `paused`, `hidden` and `detached` all called `stopTracking()`, with the message "Tracking pauses while the app is in the background". | `rider_delivery_provider.dart` `handleAppLifecycleState`; `app/app.dart` `didChangeAppLifecycleState` |
| Launch permission prompt | `bootstrapSessionLocation(requestPermission: true)` on every sign-in, before any explanation. | `app/app.dart` `_syncLocationForSession` |
| Background service | `background_location_service.dart` (flutter_background_service). Dead in practice, see below. | `services/background_location_service.dart` |
| Live orders | WebSocket `wss://rider-prod.mangaale.com/ws/rider`, plus 10 s polling of `GET /api/v1/riders/order-requests` while the socket is down. | `services/rider_socket_service.dart`, `_startFallbackPolling` |
| Ringtone | `FlutterRingtonePlayer().playNotification()`: one short sound per new request, no loop, no stop. | `_onNewDeliveryRequest`, `refreshPendingRequests` |
| Request UI | `IncomingOrderRequestSheet` opened by the dashboard for each new pending request. | `dashboard_screen.dart` `ref.listen(pendingRequests)` |
| Notifications | `flutter_local_notifications` used only by the dead background service. No delivery-request channel. | — |
| Push | `FcmService` requests permission and registers the device token (`POST /api/v1/notifications/device-token`). **rider-service stores tokens in `notification_devices` but has no code that sends a push.** | `core/services/fcm_service.dart`; rider-service `notification_repo.go` |
| Overlay / bubble | None. No `SYSTEM_ALERT_WINDOW`, no native code (`MainActivity` was empty). | `android/.../MainActivity.kt` |
| Manifest | FINE, COARSE, **BACKGROUND_LOCATION**, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS. No `<service>` override. | `android/app/src/main/AndroidManifest.xml` |

### Why the old background service never worked

1. It read the token from the prefs key `auth_token`; the app stores it
   under `access_token` (`AppConstants.preferencesAccessTokenKey`). So the
   service found no token and did nothing.
2. Its base URL came from prefs key `api_base_url`, which nothing writes,
   so it defaulted to `http://10.0.2.2:8000` (the Android emulator's host).
3. It started only for an active delivery, and `RiderLocationService.stopTracking()`
   sent it `stopService` whenever the app left the screen — the only time it
   was needed.
4. The plugin declares its service without `foregroundServiceType` and as
   `exported="true"`. Android 14+ requires the `location` type for a location
   foreground service.
5. `autoStartOnBoot` was left at the plugin default (`true`).

### ACCESS_BACKGROUND_LOCATION was declared but not needed

geolocator adds `ACCESS_BACKGROUND_LOCATION` to its permission request
whenever the manifest declares it and "while in use" is already granted
(`geolocator_android` `PermissionManager.requestPermission`). The app only
requested permission while it was still denied, so this never fired. But
declaring it triggers Google Play's background-location declaration, and a
location foreground service started from the app does not need it.

## Backend expectations

- Dispatch (`FindNearestRiders`, `delivery_repo.go`): `rider_availability`
  online, available, no current order, **and** `rider_locations.last_updated_at`
  within 5 minutes. The own-rider liveness check uses the same rule.
- `LocationService.UpdateLocation` wrote `users` and then
  `rider_locations` **discarding the second error** (`_ = s.riderRepo.UpsertRealtimeLocation`),
  so a failed dispatch-location write still returned 200.
- Sign-out (`auth_provider.dart logout`) never called go-offline. A signed-out
  rider stayed `is_online` and matchable until their last fix aged out.
- The pending-requests snapshot (`GET /api/v1/riders/order-requests`) already
  returns only the rider's `pending`, unexpired offers, using the same
  payload builder as the socket.

## Gaps this change addresses

| Gap | Addressed by |
|---|---|
| Location stops in background | Online foreground service uploads while the app is off screen |
| Requests unseen off screen | Service polls and posts a ringing heads-up notification |
| One-shot ring, never stops | Bounded ring (in-app) and insistent notification bounded by the offer expiry |
| Duplicate alerts across transports | Shared alerted-offer list across app and service |
| No disclosure before location prompt | Disclosure dialog before going Online and before "Grant Permission" |
| Sign-out left rider matchable | Logout calls go-offline first |
| Dispatch-location write error swallowed | Returned as an error so the app retries |
| No way back into the app | Optional floating bubble (opt-in) |

Not addressed (see IMPLEMENTATION_SUMMARY.md): FCM push fallback (no sender
or credentials exist), iOS background mode.
