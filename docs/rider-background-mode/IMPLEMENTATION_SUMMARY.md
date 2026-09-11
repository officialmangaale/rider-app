# Rider background mode — implementation summary

Status: **implemented, not yet tested on a device.** The authoring environment
has no Android SDK. Kotlin and the manifest merge have not been compiled, and
nothing has run on a phone. Do not call this production-ready until
MANUAL_QA_CHECKLIST.md passes on real devices.

## What it does

While a signed-in rider is **Online**, an Android foreground service keeps them
reachable when the app is minimised, behind another app, swiped away, or the
screen is locked:

- uploads location every 45 s (15 s while carrying an order) whenever the app
  has not just done so, so dispatch's 5-minute freshness rule keeps them eligible;
- every 10 s while the app is off screen, checks for delivery offers and posts
  a ringing heads-up notification for each new one, which stops when the offer
  is answered, taken or expired;
- shows "Mangaale Rider is Online" for as long as it runs.

Offline or sign-out stops all of it. Nothing runs because a rider is merely
signed in.

## Changes

### rider-app

| File | Change |
|---|---|
| `lib/features/delivery/background/*` (new) | policy, shared store, controller, foreground service, notifier, bounded ringer, prompts, platform bridge, flags |
| `providers/rider_delivery_provider.dart` | calls the background controller at every transition; one alert path (`_alertNewOffers`); alerts cancelled centrally when offers leave the list; app polling skipped off screen (the service polls) |
| `services/rider_location_service.dart` | no longer starts or stops the background service (it used to stop it on every background transition) |
| `services/background_location_service.dart` | **deleted**; replaced by `background/rider_online_service.dart` |
| `presentation/providers/auth_provider.dart` | logout goes Offline on the server first |
| `app/app.dart` | no location prompt at launch |
| `main.dart` | configures the new service (starts nothing) |
| dashboard, availability screen, location card | disclosure before Online and before the location prompt |
| `settings_screen.dart` + `widgets/online_background_settings_card.dart` | alerts, battery, bubble, "why location" |
| `android/.../AndroidManifest.xml` | − `ACCESS_BACKGROUND_LOCATION`, + `SYSTEM_ALERT_WINDOW`; service typed `location` and not exported; watchdog not exported; boot receiver disabled |
| `android/.../MainActivity.kt`, `RiderBubble.kt` | platform channel; optional overlay bubble |

### rider-service

| File | Change |
|---|---|
| `internal/dto/request.go` | optional `accuracy_meters`, `recorded_at`, `source`, `app_state`, `sequence` |
| `internal/service/location_service.go` | a failed `rider_locations` write is now an error, not a silent 200 |
| `internal/handler/location_handler.go` | debug log of source, app state and sequence (sanitised; no coordinates) |

No database migration. No change to restaurant-service, new_user_app or
restaurant-owner.

## Permissions

Added `SYSTEM_ALERT_WINDOW` (optional bubble, requested only on opt-in).
Removed `ACCESS_BACKGROUND_LOCATION`. The service runs on "while in use"
location because it is always started from the app on screen. See
PERMISSIONS_AND_POLICY.md.

## Lifecycle

- **Online** (tap, or launch while the server says Online): disclosure (first
  time) → notification permission → location permission → go-online → service
  started. It is started only with the app visible and location granted.
- **App hidden**: the in-app tracker stops; the service takes over uploads
  within one interval; alerts move to notifications; the bubble shows if
  enabled.
- **App shown**: request notifications cancelled, bubble hidden, snapshot
  fetched, in-app card and ring.
- **Offline / sign-out / session expiry**: Online flag cleared first, then
  service stopped, alerts cancelled, ring stopped, bubble hidden. Sign-out
  also calls go-offline. The service re-checks the flag every 5 s, so it
  cannot outlive the rider's choice.

## Recovery

- App resumed: pending-requests snapshot fetched, socket reconnected.
- App process killed, service alive: the service keeps polling and notifying;
  a tap opens the app, which loads the snapshot.
- Both killed: nothing runs until the rider opens the app. Android 12+ refuses
  to restart a foreground service from the background, and the watchdog
  respects that. On launch the app restores Online from the server and
  restarts the service.
- Duplicates: one offer rings once across socket, app poll and service poll
  (shared offer key and notification id).

## Tests

- rider-app: `flutter analyze` clean. `flutter test`: 115 passed, 1
  pre-existing unrelated failure (`delivery_action_policy_test.dart`, fails
  identically before this change). 53 new tests.
- rider-service: `go vet` clean, `go test ./...` all pass. 7 new tests.

## Device QA

**Not performed.** No Android SDK or device was available. Every item in
MANUAL_QA_CHECKLIST.md is outstanding, starting with `flutter build apk`.

## Known limitations

- **OEM battery managers** (Xiaomi, Oppo/Realme, Vivo, OnePlus, Samsung
  sleeping apps) can freeze or kill apps even with a foreground service.
  Mitigation in-app: the battery status and shortcut in Settings. Riders may
  still need per-brand "Autostart" or "Unrestricted" steps.
- **Doze**: with the screen off and the phone still for a long time, Android
  may defer network access. Uploads and polls resume when it lifts. A
  high-priority push is the standard mitigation, and it does not exist yet.
- **No FCM push fallback.** rider-service stores device tokens but has no
  sender, and there are no Firebase service-account credentials. Contract
  proposed in API_AND_EVENT_CONTRACTS.md.
- **Delivery within about 10 s off screen** (the service poll), or instantly
  when the app process and socket are alive. Offers last 30 s.
- **iOS unchanged**: foreground-only, as before.
- Restaurant-owned assignment alerts still use the original one-shot sound.
- Bubble has no unread badge (optional in the brief).
- No in-notification "Go Offline" action. Going Offline must reach the
  server, and doing that from a notification action safely needs its own
  isolate handling; the rider goes Offline in the app.
- `rider_location_history` is never pruned. A retention period is needed for
  the privacy policy.

## Rollback

- **Fastest, no code change**: rebuild with
  `--dart-define=RIDER_BACKGROUND_MODE_ENABLED=false`. The app reverts to
  foreground-only tracking; the service is never configured or started.
  Bubble only: `--dart-define=RIDER_OVERLAY_BUBBLE_AVAILABLE=false`.
- Full revert: revert the rider-app commit. No server state depends on it.
- rider-service change is backward compatible: old builds send fewer fields.
  Reverting it only restores the silent-200 on a failed location write.

## Before the Play Store

Foreground-service (location) declaration with video, data safety form,
privacy policy update including a location-history retention period. See
PERMISSIONS_AND_POLICY.md.
