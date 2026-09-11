/// Build-time switches for Online background mode.
///
/// The app has no remote feature-flag service, so these are compile-time
/// defines. Turning one off needs a rebuild, but no code change:
///
///   flutter build apk --dart-define=RIDER_BACKGROUND_MODE_ENABLED=false
///
/// Background mode off means the pre-existing behaviour: location and
/// requests only while the app is on screen.
library;

/// Foreground service, background location and background request alerts.
/// Location is still shared only while the rider is Online.
const riderBackgroundModeEnabled = bool.fromEnvironment(
  'RIDER_BACKGROUND_MODE_ENABLED',
  defaultValue: true,
);

/// Whether the floating-bubble setting is offered at all. Even when offered,
/// the bubble stays off until the rider turns it on and grants the overlay
/// permission.
const riderOverlayBubbleAvailable = bool.fromEnvironment(
  'RIDER_OVERLAY_BUBBLE_AVAILABLE',
  defaultValue: true,
);
