# Delivery-offer notifications (push, actions, lock screen)

Backend side, configuration and the message contract:
`rider-service/docs/offer-push-notifications.md`. This is the app side.

## What was missing

- The FCM background handler in `main.dart` was empty: even a push that reached a
  backgrounded or closed app produced nothing, and rider-service sent none.
- Device-token registration never worked: the app sent `device_token`, the
  endpoint required `push_token`. Only Android's own re-registration on every start
  was ever attempted, and `FcmService.init()` ran once per process, so a second
  rider signing in on the same phone was never registered.
- Sign-out did not unregister the token, so a phone kept receiving the previous
  rider's offers.
- The offer notification used `NotificationVisibility.public`, which overrides
  the rider's lock-screen privacy setting, and its Accept/Decline opened the app.

## Behaviour now

| App state | What the rider gets |
| --- | --- |
| Foreground | The existing offer sheet (Accept/Decline). Push and socket converge on it; no system notification. |
| Background / closed (not Force Stopped), locked or not | A heads-up, ringing notification built by the background message handler: `New delivery request #<order>`, restaurant, pickup address, delivery area, distance to pickup, order value + payment mode, with **Accept** and **Decline**. |
| Tap the body | Opens the offer sheet for that request (existing intent flow; cold start supported). |

- **Accept / Decline do not open the app.** Android runs
  `offerNotificationBackgroundHandler` in a background isolate, with or without a
  live app process. `OfferActionRunner` calls the backend with the stored token
  and reports the result by *replacing* the notification (which also removes the
  buttons, so a second tap cannot send a second request):
  - "Accepting…" while the request is in flight;
  - **"Delivery accepted #…" only after the backend returns 2xx**;
  - "Delivery already taken" (`ORDER_ALREADY_ASSIGNED`), "Request expired"
    (`OFFER_EXPIRED`), or the backend's own reason;
  - a lost response is checked against `GET /orders/active`; with no proof it says
    "Could not confirm … tap to open the app" and never claims an assignment;
  - an expired session says "Sign in to answer requests" (the runner never
    refreshes tokens; two isolates rotating one refresh token race).
- **Decline** calls only `POST …/order-requests/:id/reject`: this rider's offer.
  The customer's order and other riders' offers are untouched.
- **Duplicates:** the socket, the Online service's poll and the push share
  `alertedOfferKeys` (`requestId@expiry`) and one notification id per request, so
  an offer alerts once. The sheet dedupes by the same key.
- **Stale notifications:** removed on expiry (`timeoutAfter` = the offer's
  expiry), on accept/decline, when the poll no longer lists the offer, and by a
  `DELIVERY_ORDER_REQUEST_CLOSED` push when another rider wins (matched by order
  through a `requestId:orderId` map in shared preferences, because Android cannot
  read a notification's payload back).
- **Lock screen:** visibility is `private`, so a device set to hide sensitive
  content shows only that a request arrived. No full-screen intent, no fake call
  screen.
- **Permissions/channel:** `RequestAlertNotifier.health()` reports whether
  notifications are enabled and the importance the rider left the request channel
  at (a rider can silently lower it, which removes the heads-up). It is exposed for
  the Online flow to warn; the existing permission prompt is unchanged.
- **Token lifecycle:** registered on every session start with both key names and
  retried (3 s, 15 s, 60 s) on failure; re-registered on FCM refresh; unregistered
  on sign-out (`DELETE /notifications/device-token`) followed by `deleteToken()`.

## Files

`lib/main.dart`, `lib/core/services/fcm_service.dart`,
`lib/data/services/rider_backend_api.dart`,
`lib/presentation/providers/auth_provider.dart`, and under
`lib/features/delivery/background/`: `request_alert_notifier.dart`,
`background_mode_policy.dart`, `background_mode_store.dart`,
`background_mode_controller.dart`, and the new `offer_action_runner.dart`,
`offer_notification_entry.dart`, `offer_push_handler.dart`.

## Verification

`flutter analyze` (lib + test) clean; `flutter test`: 193 pass, including 33 new in
`offer_push_and_actions_test.dart` (payload parsing; push handler dedupe/expiry/
signed-out/closure; every accept/decline outcome against a mock backend, including
ordering — no "assigned" before the 2xx — lost responses and repeated taps;
notification details through the plugin's method channel: importance, private
visibility, body text, background action flags and callback registration, channel
health).

## Not verified (needs a device with FCM)

Real FCM delivery to a backgrounded/closed/locked phone; the heads-up popup and
ringtone on real hardware and per OEM (battery managers can delay or drop
background messages); the background action isolate starting on a real device;
lock-screen redaction; behaviour after Force Stop (not delivered, by Android's
design). **iOS is not implemented or tested**: it needs the `DELIVERY_OFFER`
category registered and a Mac.
