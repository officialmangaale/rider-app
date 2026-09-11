# Rider background mode — architecture

## The rule

| Rider state | Location | Requests | Foreground service | Bubble |
|---|---|---|---|---|
| Signed in, **Online** | Shared, app on screen or not | Delivered on screen and off | Running, with notification | Only if opted in and permitted, and app off screen |
| Signed in, Offline | Not shared | Not dispatched | Not running | Hidden |
| Signed out | Not shared | — | Not running | Hidden |

Being signed in is never consent to be tracked. Online is an explicit toggle,
and the "Mangaale Rider is Online" notification is shown for as long as the
service runs.

## Components

```
lib/features/delivery/background/
  background_mode_policy.dart      pure rules: when to run, upload, poll, alert, show bubble
  background_mode_store.dart       SharedPreferences keys shared by app and service
  background_mode_controller.dart  app-side owner: start/stop service, alerts, bubble
  rider_online_service.dart        the foreground service (its own Dart isolate)
  request_alert_notifier.dart      notification channels, ringing request alerts
  incoming_ringer.dart             bounded in-app ring while the app is on screen
  online_mode_prompts.dart         disclosure + notification permission before Online
  rider_platform.dart              MethodChannel to MainActivity.kt (bubble, battery)
  background_mode_flags.dart       build-time rollout switches
android/.../MainActivity.kt        channel com.mangaale.rider/platform
android/.../RiderBubble.kt         the optional overlay bubble
```

`RiderDeliveryController` (`providers/rider_delivery_provider.dart`) remains
the single source of Online truth. It calls the background controller at each
transition and never duplicates its logic.

## Two isolates

The foreground service runs a separate Dart isolate (flutter_background_service
starts its own Flutter engine). It survives the rider swiping the app away,
because the plugin's service is `stopWithTask=false`. The app isolate and the
service cannot share objects, so they share a few SharedPreferences keys
(`BackgroundModeStore`). Each side calls `reload()` before acting on a value
the other may have written.

| Key | Written by | Read by | Meaning |
|---|---|---|---|
| `rider_bg_online` | app | service | the service's licence to run |
| `rider_bg_active_delivery` | app | service | 15 s uploads and high accuracy |
| `rider_bg_app_foreground` | app | service | who alerts: app or service |
| `rider_bg_last_upload_ms` | both | service | skip an upload the other side just made |
| `rider_bg_alerted_offers` | both | both | one offer rings once (bounded to 100) |
| `rider_bg_sequence` | service | service | upload sequence number |
| `rider_bubble_enabled` | app | app | bubble opt-in (default off) |
| `rider_bg_disclosure_accepted_v1` | app | app | disclosure seen and accepted |

## Lifecycle

```mermaid
sequenceDiagram
  participant R as Rider
  participant App as App isolate
  participant S as Online service
  participant API as rider-service
  R->>App: taps Online
  App->>R: disclosure (first time) + notification permission
  App->>App: location permission (Android prompt)
  App->>API: POST go-online
  App->>S: start (app on screen, location granted)
  S->>R: "Mangaale Rider is Online" notification
  loop every 5 s tick
    S->>S: reload store; stop if not Online or no token
    S->>API: POST /location/update (if due: 45 s idle, 15 s delivering)
    S->>API: GET /riders/order-requests (every 10 s, only while app off screen)
    S->>R: ringing heads-up notification for each new offer
  end
  R->>App: taps Offline / logs out
  App->>API: POST go-offline
  App->>S: clear Online flag, then stop command
  S->>S: cancel alerts, stopSelf
  App->>R: bubble hidden, ring stopped
```

Stop guarantees, in order of robustness:

1. `stopOnline()` clears `rider_bg_online` **before** anything else.
2. It sends the `stopService` command.
3. Even if the command is lost, the service re-reads the flag every 5 s and
   stops itself (`mayRunOnlineService`). The same check stops a service
   restarted by the plugin's watchdog after sign-out.
4. Boot autostart is disabled twice: `autoStartOnBoot: false` in code, and
   `BootReceiver` disabled in the manifest.

Starting only happens with the app on screen and location granted (Online
tap, or launch while the server says Online). Android 14 refuses a location
foreground service started otherwise, and the failed start would crash the
app, so `startOnline(locationGranted: false)` deliberately does not start it.

## Location ownership

- **App on screen:** the existing in-app tracker (unchanged cadence) uploads
  and records each success in `rider_bg_last_upload_ms`.
- **App off screen, swiped away, or screen locked:** the in-app stream stops
  as before. The service sees no recent upload and takes over within one
  interval: 45 s idle (six fixes per 5-minute dispatch window) or 15 s while
  carrying an order. Balanced accuracy while idle, high while delivering.
- **No queue.** A failed upload is retried 15 s later with a fresh fix. Old
  fixes are never replayed.

## Request alert routing

| Where the offer arrives | App on screen | App off screen (process alive) | App process gone |
|---|---|---|---|
| Socket event | in-app card + bounded ring | heads-up notification from the app | — |
| App poll (socket down) | in-app card + bounded ring | skipped; service polls instead | — |
| Service poll (10 s) | not polled | heads-up notification | heads-up notification |
| App launch / resume | snapshot loaded, card shown | — | snapshot on launch |

De-duplication: an offer is `request_id@expires_at` (`requestOfferKey`).
Before alerting, either side checks and appends to `rider_bg_alerted_offers`.
Notifications use the id `1000000 + request_id` with `onlyAlertOnce`, so even
a race between the two sides produces one notification and one sound.

Stopping an alert:

- **In app** (`IncomingRinger`): stops on accept, decline, the list emptying
  (expiry, another rider accepted), Offline, sign-out, or the app leaving the
  screen. Hard cap: the offer's expiry or 45 s.
- **Notification**: `FLAG_INSISTENT` repeats the ringtone until cancelled,
  bounded by `timeoutAfter` = time left on the offer, so at most about 30 s.
  Cancelled when the offer leaves the service's poll, when it leaves the
  app's list, on app resume (the card takes over), on accept or decline, and
  on Offline or sign-out.

## Floating bubble

Optional, off by default, and never needed to receive requests. Shown only
when all of these hold: Online, app off screen (`paused`/`hidden`, never
`inactive`, so it cannot appear over a permission dialog), opted in, and
`Settings.canDrawOverlays`. Tap opens the app; drag to move. It is not drawn
on the lock screen (overlay windows are not). It is hidden on resume, Offline
and sign-out. If the permission is revoked it simply is not shown. It keeps
nothing alive.
