# Manual QA — physical Android device (mandatory before release)

Use a real phone, not an emulator: OEM battery managers are the main risk.
Test with a second phone or the web to place orders. Keep rider-service logs
open (`docker logs -f <rider-service>`).

Backend freshness check (read-only; replace the rider id):

```sql
SELECT last_updated_at, NOW() - last_updated_at AS age
FROM rider_locations WHERE rider_id = '<rider user id>';
```

## 0. Build

- [ ] `flutter build apk --debug` succeeds (Kotlin and manifest merge were
      not compiled in the authoring environment).
- [ ] Fresh install (uninstall first, to clear old notification channels).

## 1. First Online

- [ ] Log in. **No** location prompt appears at launch.
- [ ] Tap Online. The disclosure dialog appears; "Not now" keeps you Offline.
- [ ] Tap Online again, then Continue. On Android 13+ the notification
      permission prompt appears, followed by the location prompt ("While
      using the app"; no "Allow all the time" option is requested).
- [ ] The "Mangaale Rider is Online" notification appears and cannot be
      swiped away.

## 2. Background location

- [ ] Press Home. Wait 3 minutes. The SQL `age` is under 1 minute.
- [ ] Open another app (e.g. YouTube) for 3 minutes. `age` stays under 1 minute.
- [ ] Lock the screen for 5 minutes. `age` stays under 1 minute. Note if the
      phone delays it; see the OEM notes below.
- [ ] Swipe the app away from Recents. The notification stays; `age` stays fresh.

## 3. Requests while in the background

- [ ] App on the home screen. Place an order and have the owner accept it.
- [ ] Within about 10 s a heads-up "New delivery request" notification rings
      with the phone ringtone. It shows restaurant, distance and amount only.
- [ ] Leave it: ringing stops by the offer's expiry (about 30 s) and the
      notification disappears.
- [ ] Next offer: tap the notification. The app opens with the request card.
      The ringing stops and does **not** start again in-app.
- [ ] Accept. The customer app shows the rider. The owner app shows the rider.
- [ ] With two riders Online: when one accepts, the other's notification or
      card disappears.
- [ ] Decline an offer: it is not re-offered to you; the order is not cancelled.
- [ ] Screen locked: the notification shows on the lock screen and rings.

## 4. In-app

- [ ] App open: a new request shows the card and rings until you accept or
      decline, or the offer expires. It never rings more than 45 s.
- [ ] Press Home mid-ring: the in-app ring stops (the notification path
      takes over only for offers not yet alerted).

## 5. Bubble (optional feature)

- [ ] Settings → "Floating rider bubble": off by default.
- [ ] Turn it on. The explanation appears, then the system "Display over
      other apps" screen. Grant it.
- [ ] Press Home while Online: the bubble appears. Drag it; tap it and the
      app opens and the bubble disappears.
- [ ] Not shown on the lock screen. Not shown while a permission dialog is
      open. Not shown while Offline.
- [ ] Revoke the permission in system settings: no bubble, no crash.
- [ ] Turn it off: it disappears immediately.

## 6. Stop

- [ ] Tap Offline: the notification disappears, the bubble disappears, any
      ringing stops. After 5 minutes the rider is no longer matched (SQL
      `age` keeps growing; no new rows).
- [ ] Online again, then Log out: everything stops;
      `rider_availability.is_online` is false immediately.
- [ ] Reboot the phone: the service does **not** start by itself.

## 7. Permissions and settings

- [ ] Deny location: Online is refused with the existing message.
- [ ] Deny notifications: you go Online with a warning. Settings shows
      "Request alerts: Off" with Allow.
- [ ] Turn GPS off while Online and backgrounded: the notification says "GPS
      is off".
- [ ] Settings → Battery optimisation shows the status; Open goes to the system list.

## Android versions

- [ ] Android 10 (API 29)
- [ ] Android 11/12
- [ ] Android 13 — notification permission prompt
- [ ] Android 14/15 — foreground-service type enforcement (the service must
      start without a crash)

## OEM notes

Xiaomi/Redmi (MIUI/HyperOS), Oppo/Realme (ColorOS), Vivo, OnePlus and
Samsung "Sleeping apps" can freeze or kill apps despite a foreground service.
On each brand you test, record whether sections 2 and 3 pass with the
default battery setting and after setting the app to Unrestricted / Autostart
allowed. Riders on these phones will need the same instructions.
