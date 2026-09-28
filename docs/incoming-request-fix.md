# Incoming delivery request presentation fix

The subsequent Prepare-trigger/backend investigation is recorded in
`../../restaurant-service/docs/prepare-live-request-investigation.md`, including
the disabled-dispatch deployment check, independent preparation dispatch,
eligibility diagnostics and real PostgreSQL/WebSocket journey validation.

## Confirmed findings and scope

> **Update 2026-09-26:** the recording (order #14659) has since been analysed. Its first
> failure was upstream of this app: no offer was ever created because the production
> database lacks migrations 078/095/096/097. See
> `../../restaurant-service/docs/dispatch-missing-migrations-investigation.md`. The
> presenter defects below are real but were not what the recording shows.

The screen recording was not available when this was first written, so the findings
below were derived from source and tests only. These findings come from
the checked-out source and automated regression tests. Existing live delivery,
notifications, dispatch eligibility and order lifecycle are retained.

The UI break was in `DashboardScreen`: its only automatic incoming-request
listener used the Dashboard's context to call `showModalBottomSheet` without
`useRootNavigator`. Each tab has a separate Navigator inside
`StatefulShellRoute.indexedStack`. After switching tabs, the Dashboard listener
could open a sheet in an **offstage** navigator. Entering a different tab before
Dashboard was built meant no listener existed. The listener also had no initial
snapshot handling, and opened one stacked sheet for every new request.

The existing Android `RequestAlertNotifier` already posted ringing request
notifications from the app/service isolates. It did not include actions, register
`onDidReceiveNotificationResponse`, or read notification launch details. FCM tap
handling refreshed lists but discarded the tapped request identity. FCM
initialization also lived on Dashboard instead of the authenticated app lifetime.

Other confirmed failure cases: an incoming refresh was dropped if another pending
GET was in flight; malformed expiry invented a new 30-second offer; a failed
Decline always dismissed its sheet; and expiry could pop a sheet during acceptance.
Backend Decline ignored affected-row count, so an acceptance race could return a
false successful decline. These are fixed without changing the live transport.

## Traced contract

1. Restaurant `routes/routes.go` status callback re-reads the canonical order.
   Preparing or direct Ready passes `IsMangaaleDelivery`,
   `IsDispatchPreparationStatus`, and the existing database feature flag.
   It publishes the existing `ORDER_PLACED` SQS dispatch event. An order-status
   notification alone is not a delivery offer.
2. Rider `DeliveryService.ProcessOrderPlacedEvent` rechecks the authoritative
   order. Existing nearby-rider selection checks account role/status, online,
   available, workload, valid fresh location and configured radius.
3. `sendRequestsToRiders` persists `delivery_order_requests` before sending
   `{type: "DELIVERY_ORDER_REQUEST", data: {...}}` through `SendToRiderCount`.
   `BuildDeliveryOrderRequestPayload` and authenticated
   `GET /api/v1/riders/order-requests` share the payload: `request_id`, `order_id`,
   pickup/restaurant preview, distance/amount, and RFC3339 `expires_at`.
   Recipient identity is enforced by the targeted socket and authenticated GET;
   `rider_id` is not a required field in this preview. The payload has no status
   field: the GET is filtered to pending, live and currently offerable requests.
4. `RiderSocketService` recognizes `DELIVERY_ORDER_REQUEST`, parses
   `RiderOrderRequestModel`, and triggers REST reconciliation. General
   `ORDER_STATUS_UPDATED` / assignment events retain their existing behavior.
   Numeric/string IDs parse correctly. Missing offer IDs/expiry cannot establish
   an actionable request.
5. The app-wide `IncomingRequestHost` displays one root-navigator sheet at a time,
   including existing pending offers at launch. It is independent of rider tab,
   city display, KYC display, or location-status card. Dedupe uses request ID plus
   server expiry because an expired request row can be reopened by redispatch.
6. Accept uses `POST /api/v1/riders/order-requests/:requestId/accept`, with the
   existing atomic backend assignment and lost-response recovery through
   `GET /api/v1/orders/active`. Decline uses the existing `.../:requestId/reject`;
   it only rejects this offer. Other offers/redispatch remain available and the
   customer order/payment are untouched. Expired or already-responded declines
   return conflict; retrying an already-declined offer succeeds idempotently.
7. Assignment is written to the shared canonical order within the existing
   transaction. The existing `syncRiderAssignmentAsync` callback triggers
   restaurant/customer invalidation; existing polling remains the fallback.
   This fix adds no second assignment or synchronization mechanism.

## Notification behavior

Android keeps the existing high-importance channel, stable notification ID,
permission flow, ringing and backend-derived timeout. Accept and Decline actions
use `showsUserInterface: true`: Android opens the app (and may require unlocking),
then the authenticated pending API validates the exact request/order/expiry before
performing the selected action. The app does not assign while trusting a push
payload. Old notification payloads still open the corresponding request.
The main isolate shares one notifier owner to avoid overwriting its callback.

This uses the plugin's documented [notification action behavior](https://pub.dev/packages/flutter_local_notifications#notification-actions).
No full-screen-intent, overlay or eligibility bypass was added.

FCM listeners and existing status/order refreshes are retained. Actionable push
taps require `type=DELIVERY_ORDER_REQUEST` and a positive `request_id`; `order_id`
and `expires_at`, when present, must match the authenticated response. Ordinary
status pushes refresh state without inventing an offer or executing an action.
The Android online service still obtains live offers through the same pending GET
and posts local notifications while backgrounded. Live and push hints converge on
the same presentation queue.

**Unavailable sender/platform contract:** this rider-service checkout registers
device tokens and stores notification records, but its offer dispatch code has no
FCM/APNs sending call. The source of any externally supplied rider push was not
available. Android notification actions are implemented for the existing local
request-alert path. Adding buttons to an external push, especially iOS APNs, also
requires that sender's actionable-offer payload and iOS category/action handler.
This Android-focused alert implementation does not claim iOS action support or
guaranteed delivery after force-stop. Existing FCM reception is not replaced.

## Location, city and KYC labels

- `City not set` is the profile model's fallback for missing city data. The nearby
  dispatch SQL uses coordinates, not that label.
- `Checking location permission...` is a transient controller state while starting
  tracking. Real missing/stale GPS can affect backend eligibility; the label alone
  does not establish that an offer was rejected. No GPS check was bypassed.
- The profile license/document status and compliance `kycVerified` /
  `isKycComplete` are separate sources. Document completion can coexist with
  pending verification. The current nearby/claim SQL does not use the rendered
  KYC label. Without recording/account responses, which label was stale is not
  confirmed. No KYC/online policy was loosened.

## Changed files

Rider app:

- `lib/app/app.dart`: install the global presenter and initialize notifications.
- `lib/core/services/fcm_service.dart`: one listener registration, preserve
  foreground refreshes and route request-specific notification taps.
- `lib/features/dashboard/presentation/dashboard_screen.dart`: remove tab-local
  presentation; route the existing badge through the common presenter.
- `lib/features/delivery/widgets/incoming_request_host.dart`: presentation queue,
  lifecycle, targeted notification validation, root navigator and deduplication.
- `lib/features/delivery/widgets/incoming_order_request_sheet.dart`: existing
  Accept/Decline component, expiry/race/error handling and notification actions.
- `lib/features/delivery/models/delivery_request_intent.dart` and
  `providers/request_notification_provider.dart`: typed notification routing.
- `lib/features/delivery/background/request_alert_notifier.dart` and
  `android/app/src/main/AndroidManifest.xml`: Android actions, tap/cold-launch
  handling, existing-channel preservation and action receiver.
- `lib/features/delivery/providers/rider_delivery_provider.dart`: coalesced
  reconciliation, action mutex, malformed-offer rejection and clear missing-API
  errors. Existing assignment/recovery APIs remain in use.
- `lib/features/delivery/models/delivery_models.dart`: require server expiry.
- `lib/features/orders/presentation/orders_screen.dart`: consistent Decline label.
- `test/features/delivery/{incoming_request_flow,request_controller,request_notification_contract}_test.dart`.

Rider backend:

- `internal/repository/delivery_repo.go`: decline only an unexpired pending row
  and check the affected-row count.
- `internal/service/delivery_service.go`: idempotent successful decline retry.
- `internal/service/incoming_request_postgres_test.go`: decline authorization,
  expiry, customer-order preservation, next rider acceptance and race tests.

No new migration, endpoint, dispatch flag, production rollout or change to either
restaurant repository is required for this presentation fix. It uses the already
implemented online-delivery backend contract, including migration 097 where that
backend is deployed. Existing unrelated staged/generated/lockfile changes were
not part of this fix.

## Verification

- `flutter analyze --no-pub` reports no issues.
- `flutter build apk --debug --no-pub` succeeds. The compiled artifact is
  `build/app/outputs/flutter-apk/app-debug.apk`. Existing Kotlin/Java deprecation
  warnings remain; this is a debug build, not a published release.
- All 160 Flutter tests pass, including 24 new widget/controller/notification
  tests. They cover non-Dashboard tabs, initial/reconnect snapshots, background
  then foreground, targeted warm/cold notification routing, both actions,
  duplicate snapshots/taps, failed decline retry, lost acceptance response,
  cancellation, expired/reissued offers, and expiry during an in-flight action.
- Notification tests exercise the real plugin through a mocked native method
  channel, checking actions, launch callback, IDs and timeout. They are not a
  physical Android lock-screen test.
- Rider `go test ./...` passes. `TestOnlineDispatch*` passes against an isolated
  local PostgreSQL 18 database, including new Accept/Decline races and canonical
  assignment after another rider declines. Existing PostgreSQL fixture suites
  outside that selected suite were not run.
- No Android device is connected (`adb devices` returned an empty list). Live
  FCM/SQS, installed app background/lock-screen behavior, restaurant/customer
  screens and a deployed end-to-end journey still require staging validation.
  No unavailable component was simulated as a successful production response.

For device validation, keep one rider on Earnings/Profile while entering Preparing,
then repeat with the app backgrounded and the phone locked. Tap the notification
body, Accept and Decline separately. Test reconnect, two identical event sources,
expiry and another rider winning. Verify the restaurant/customer display from the
real shared assignment. Record `order_id`, `request_id`, rider identity and server
expiry from dispatch logs; do not substitute a general order notification for a
persisted delivery offer.
