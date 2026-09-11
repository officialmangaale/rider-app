# Permissions, Play policy and privacy

## Android permissions

| Permission | Before | After | Why |
|---|---|---|---|
| ACCESS_FINE_LOCATION / COARSE | declared | declared | location while Online |
| ACCESS_BACKGROUND_LOCATION | declared (never requested) | **removed** | not needed; see below |
| FOREGROUND_SERVICE | declared | declared | Online service |
| FOREGROUND_SERVICE_LOCATION | declared | declared | Android 14 location-type service |
| POST_NOTIFICATIONS | declared | declared | Online notification, request alerts (Android 13+) |
| SYSTEM_ALERT_WINDOW | — | **added** | optional bubble; requested only when the rider turns it on |
| RECEIVE_BOOT_COMPLETED, WAKE_LOCK | from plugin | from plugin | plugin manifest; boot receiver is disabled |

Manifest service overrides: `BackgroundService` gets
`foregroundServiceType="location"` and `exported="false"`. `WatchdogReceiver`
gets `exported="false"`. `BootReceiver` gets `enabled="false"`.

### Why "while in use" is enough

Android treats location access by a foreground service of type `location`
as while-in-use access, provided the service was started while the app was
visible. The Online service is only ever started from the app on screen (the
Online tap, or launch while Online). So the rider is asked only for "While
using the app" location, never "Allow all the time". This also avoids
Google Play's background-location permission declaration.

Consequence: if Android kills the service and its watchdog restarts it with
the app off screen, Android 12+ refuses the restart. The service therefore
stays down until the rider opens the app. It is not restarted invisibly.

### Runtime flow

1. Rider taps Online. The **disclosure dialog** appears the first time
   (`online_mode_prompts.dart`):

   > Mangaale uses your location while you are Online so nearby delivery
   > requests can reach you and customers can track deliveries assigned to
   > you. While you are Online this continues when the app is closed or the
   > screen is off, and a "Mangaale Rider is Online" notification is always
   > shown. Tracking stops when you go Offline or log out.

   "Not now" keeps the rider Offline.
2. Notification permission (Android 13+). If refused, the rider goes Online
   anyway with a warning that requests cannot ring while the app is closed.
3. Android location prompt, as before (`toggleOnline` → `checkReadiness`).
   The app no longer asks at launch.
4. The "Grant Permission" button on the location card also shows the
   disclosure first.

Handled states: foreground location denied or permanently denied (existing
card: grant, or open app settings); precise location off (existing
reduced-accuracy state); GPS off (existing "Enable GPS"; the service
notification also says "GPS is off"); permission revoked while Online (the
service notification says "location is off" and skips uploads); battery
optimisation (Settings shows the status and opens the system list).

The battery shortcut opens the system list
(`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`) instead of the direct prompt.
The direct prompt needs `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which Play
restricts.

## Google Play — required before publishing

- **Foreground service declaration** (apps targeting Android 14+): declare
  the `location` foreground-service type in Play Console → App content, with
  a description and a short video of: Online tap → notification → app
  minimised → location continuing → Offline stops it.
- **Prominent disclosure**: shown in-app before the location prompt (above).
  Keep the wording consistent with the store listing and privacy policy.
- **Data safety form**: approximate and precise location, collected, not
  shared for advertising, required for app functionality, collected while
  Online including in the background.
- **Display over other apps**: allowed for a user-initiated feature. It is
  opt-in with its own explanation and can be turned off in Settings.
- Background-location declaration: **not** required now that
  `ACCESS_BACKGROUND_LOCATION` is not declared. Confirm in Play Console that
  no earlier release's declaration is still pending.

## Privacy disclosure content (for the privacy policy)

- **What:** latitude, longitude, accuracy, heading and speed, plus a
  sequence number and whether the app was in the foreground.
- **When:** only while the rider is Online, including when the app is closed
  or the screen is off. Never while Offline or signed out.
- **How to stop:** go Offline or log out. The persistent notification is
  shown the whole time.
- **Who sees it:** Mangaale dispatch (to offer nearby requests), the
  restaurant for the order being delivered, and the customer for a delivery
  assigned to that rider.
- **Retention:** the latest position (`rider_locations`) is overwritten on
  each update. History (`rider_location_history`) is **currently never
  pruned**. A retention period must be decided and implemented before the
  policy can state one; this was flagged in an earlier audit.

## Security notes

- The service is no longer exported, so other apps cannot start it.
- Requests carry only a Bearer token read from app storage; the service never
  refreshes tokens, which avoids a refresh race that could sign the rider out.
- Notifications carry restaurant, distance and amount only: no customer name,
  phone or drop address, since they can appear on the lock screen before the
  rider has accepted.
- Logs: service logs are debug-only and carry no token, coordinates or offer
  content. Backend per-update logs are debug-level, and client-supplied labels
  are sanitised before logging.
