# API and event contracts

No endpoint was added or removed. One request body gained optional fields.

## POST /api/v1/location/update (rider-service)

From the Online service:

```json
{
  "latitude": 28.4595,
  "longitude": 77.0266,
  "accuracy_meters": 20,
  "heading": 120,
  "speed": 4.3,
  "recorded_at": "2026-09-11T06:30:00.000Z",
  "source": "foreground_service",
  "app_state": "background",
  "sequence": 1042
}
```

- `heading` and `speed` keep the names the endpoint already had. The brief's
  `heading_degrees` / `speed_mps` are the same values (degrees, m/s).
- Everything after `longitude` is optional. Older builds send only
  coordinates. Unknown values (NaN, negative) are omitted, not sent.
- `recorded_at` is **informational**. Dispatch freshness uses the server's
  receive time, because phone clocks drift by minutes and a slow clock would
  push a live rider toward the 5-minute cutoff. The service always takes a
  fresh fix before uploading, so receive time is accurate.
- Behaviour change: if the write to `rider_locations` (the table dispatch
  reads) fails, the endpoint now returns 500 instead of 200, so the app
  retries on its next tick.
- Logs: `[LOCATION] Update received rider_id=… source=… app_state=… seq=…`
  at debug level (`APP_ENV=development` or `GIN_MODE=debug`). This is the
  `rider_location_background_update_received` signal. Failures are always
  logged. Coordinates are never logged.

## GET /api/v1/riders/order-requests — active request snapshot

Unchanged. It returns the rider's `pending`, unexpired offers, built by the
same function as the socket event. It is loaded at app launch, on resume, on
socket reconnect, every 10 s by the app while the socket is down and the app
is on screen, and every 10 s by the Online service while the app is off
screen. It is the recovery path when the app process was killed.

## Socket events (unchanged)

`DELIVERY_ORDER_REQUEST`, `ORDER_REQUEST_EXPIRED`,
`ORDER_ASSIGNED_TO_OTHER_RIDER`, `order_assigned`. See
rider-service `docs/rider-dispatch/API_AND_EVENT_CONTRACTS.md`.

## Offer identity

`requestOfferKey = "<request_id>@<expires_at, whole UTC seconds>"`. A lapsed
offer that is re-offered (same request id, new expiry) is a new offer and
rings once. A replay of the same offer never rings twice.

## App ↔ service commands (flutter_background_service `invoke`)

| Command | Effect |
|---|---|
| `refresh` | tick now (after going Online, or when the app leaves the screen) |
| `stopService` | cancel alerts and stop |

## Notifications

| Channel id | Name | Importance | Used for |
|---|---|---|---|
| `rider_online_status` | Online status | low, silent | the persistent foreground-service notification (id 888) |
| `rider_delivery_requests_v1` | Delivery requests | max, phone ringtone, vibration | one per offer, id `1000000 + request_id`, insistent, times out at offer expiry |

The legacy `rider_location_channel` is deleted on first run. Tapping a
request notification opens the app; the resume snapshot shows the card.

## Platform channel `com.mangaale.rider/platform` (Android)

`canDrawOverlays` → bool, `openOverlaySettings`, `showBubble`, `hideBubble`,
`isIgnoringBatteryOptimizations` → bool, `openBatteryOptimizationSettings`.
Each call degrades to a no-op off Android.

## Push fallback — not implemented

rider-service stores FCM tokens (`notification_devices`) but has no sender,
and no Firebase service-account credentials exist in any service. Proposed
contract when it is built: a high-priority **data** message
`{"type":"DELIVERY_ORDER_REQUEST","request_id":"901","expires_at":"…"}`
sent alongside the socket push. The app's background handler would post the
same request notification (`RequestAlertNotifier.showRequest`), and the
shared offer key would keep it to one ring. It should sit behind a server
flag `RIDER_REQUEST_PUSH_FALLBACK_ENABLED`.
