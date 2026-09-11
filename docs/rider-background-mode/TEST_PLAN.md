# Test plan

## Automated — added with this change

### rider-app (`flutter test`)

| File | Covers |
|---|---|
| `background_mode_policy_test.dart` (24) | never runs Offline or signed out; upload cadence 45 s / 15 s; retry backoff; no polling while on screen; bubble only when all four conditions hold; post / skip-already-alerted / cancel-gone / never-post-expired; bounded alerted list; notification ids; snapshot parsing; lock-screen-safe text; location payload contract |
| `background_mode_controller_test.dart` (14) | going Online starts the service; no double start; no start without location permission; iOS no-op; Offline and sign-out stop the service, alerts and bubble; Online flag cleared; rider settings kept; resume cancels alerts and hides the bubble; bubble only when opted in and permitted; never Offline; flag-off build; overlay permission flow |
| `rider_online_service_test.dart` (8) | service stops itself when Offline or signed out; stop command silences alerts and stays stopped; one notification per new offer with auth header; no repeat ring; no ring for an offer the app already alerted; stops ringing when the offer disappears; leaves alerting to the app on screen |
| `incoming_ringer_test.dart` (7) | rings for a live offer; never for an expired one; no restart on a second offer; stops on command; stops at expiry; hard cap; no-op stop |
| `incoming_alert_policy_test.dart` (existing, still passing) | offer keys, replay silence |

Result: `flutter analyze` — no issues. `flutter test` — 115 passed, 1 failed.
The failure is `delivery_action_policy_test.dart` ("restaurant-owned
picked-up order can only be delivered"). It fails identically on the commit
before this change and is unrelated.

### rider-service (`go test ./...`)

| Test | Covers |
|---|---|
| `handler/location_handler_test.go` | foreground-service fields accepted; an odd `recorded_at` never rejects an update; legacy body; log-label sanitising |
| `service/location_service_test.go` | an update writes `rider_locations` (keeps the rider eligible); a failed write now returns an error |
| `repository/pending_requests_test.go` | the snapshot returns only this rider's pending, unexpired offers |

Existing tests cover the rest of the eligibility rules the brief lists:
`own_rider_liveness_test.go` and `FindNearestRiders` (stale fix excluded
after 5 minutes, offline and busy excluded). Go-offline sets both
availability flags false (`RiderService.GoOffline`).

Result: `go vet ./...` clean, `go test ./...` all pass.

## Not automatable here

There is no Android SDK or device in this environment, so the following were
**not** run:

- Kotlin compile (`MainActivity.kt`, `RiderBubble.kt`) and manifest merge.
  Run `flutter build apk --debug` first.
- Foreground service start, notification, swipe-away survival.
- Background location uploads, heads-up notification and ringtone, bubble.

These are covered step by step in MANUAL_QA_CHECKLIST.md. Candidates for a
later `integration_test` on a device farm: service starts with notification,
stops on Offline, bubble visible only while Online.
