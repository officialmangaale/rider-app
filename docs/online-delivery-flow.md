# Rider app delivery changes

Branch `feat/online-delivery-flow-20260924` was cut from local
`feat/nearby-delivery-dispatch` at `9fc0085` (GitHub: rider-app).

Socket offers now trigger authoritative refresh. Resume, reconnection, polling,
notification tap and cold-launch push refresh delivery state. Acceptance errors
check the active assignment before reporting failure, covering a lost success
response. Loading, empty, failed, assigned and expired requests have distinct
handling. Order total is labeled correctly rather than being presented as payout.
Offers show approximate delivery distance; full customer details come only from
the assigned-delivery response. Existing pickup readiness and navigation ordering
are retained. The historical restaurant-owned picked-up action was aligned with
its backend contract and existing test (Mark delivered).

Validation: `flutter test --no-pub` passes all 136 tests;
`flutter analyze --no-pub` reports no issues. Real device
background operation, notifications, navigation and older app interoperability
still require staging. Use the matching backend feature branches with migration
097, following restaurant-service `docs/online-delivery-flow.md`.

No production build was published. An existing deletion under
`android/.kotlin/sessions` was present before this work and is unrelated.
