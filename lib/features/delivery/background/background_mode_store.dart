import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import 'background_mode_policy.dart';

/// State shared between the app and the Online foreground service.
///
/// The service runs its own Dart isolate, so the two sides cannot share
/// objects. They share these SharedPreferences keys instead. Each side keeps
/// its own in-memory copy, so a reader calls [reload] before acting on a
/// value the other side may have written.
///
/// The service treats [online] as its licence to run: it stops itself on any
/// tick where the rider is not Online or has no session.
class BackgroundModeStore {
  BackgroundModeStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onlineKey = 'rider_bg_online';
  static const _activeDeliveryKey = 'rider_bg_active_delivery';
  static const _appForegroundKey = 'rider_bg_app_foreground';
  static const _lastUploadKey = 'rider_bg_last_upload_ms';
  static const _sequenceKey = 'rider_bg_sequence';
  static const _alertedKey = 'rider_bg_alerted_offers';
  static const _offerOrdersKey = 'rider_bg_offer_orders';
  static const _bubbleEnabledKey = 'rider_bubble_enabled';
  static const _disclosureKey = 'rider_bg_disclosure_accepted_v1';

  Future<void> reload() => _prefs.reload();

  bool get online => _prefs.getBool(_onlineKey) ?? false;
  Future<void> setOnline(bool value) => _prefs.setBool(_onlineKey, value);

  bool get hasActiveDelivery => _prefs.getBool(_activeDeliveryKey) ?? false;
  Future<void> setActiveDelivery(bool value) =>
      _prefs.setBool(_activeDeliveryKey, value);

  /// Defaults to true: until the app says otherwise, assume it is on screen
  /// and handling alerts itself, so nothing rings twice.
  bool get appInForeground => _prefs.getBool(_appForegroundKey) ?? true;
  Future<void> setAppInForeground(bool value) =>
      _prefs.setBool(_appForegroundKey, value);

  String? get accessToken =>
      _prefs.getString(AppConstants.preferencesAccessTokenKey);

  DateTime? get lastUploadAt {
    final ms = _prefs.getInt(_lastUploadKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastUploadAt(DateTime value) =>
      _prefs.setInt(_lastUploadKey, value.millisecondsSinceEpoch);

  /// Monotonic per-install counter for uploads from the service, so gaps are
  /// visible in server logs. Only the service writes it.
  Future<int> nextSequence() async {
    final next = (_prefs.getInt(_sequenceKey) ?? 0) + 1;
    await _prefs.setInt(_sequenceKey, next);
    return next;
  }

  /// Offers either side has already alerted for (see [requestOfferKey]).
  Set<String> get alertedOfferKeys =>
      (_prefs.getStringList(_alertedKey) ?? const <String>[]).toSet();

  Future<void> rememberAlerted(Iterable<String> keys) async {
    // Both sides append to this list: re-read first so neither overwrites
    // keys the other has just added.
    await _prefs.reload();
    final existing = _prefs.getStringList(_alertedKey) ?? const <String>[];
    await _prefs.setStringList(
      _alertedKey,
      rememberAlertedOfferKeys(existing, keys),
    );
  }

  /// Which order each posted offer notification is about, as `requestId:orderId`
  /// pairs. A notification is identified by its request id, but "another rider
  /// took it" arrives naming the order, and on Android a notification's payload
  /// cannot be read back to find the match. Both isolates write it.
  Future<void> rememberOfferOrder(int requestId, int orderId) async {
    await _prefs.reload();
    final existing = _prefs.getStringList(_offerOrdersKey) ?? const <String>[];
    final merged = <String>[
      ...existing.where((entry) => !entry.startsWith('$requestId:')),
      '$requestId:$orderId',
    ];
    await _prefs.setStringList(
      _offerOrdersKey,
      merged.length <= maxAlertedOfferKeys
          ? merged
          : merged.sublist(merged.length - maxAlertedOfferKeys),
    );
  }

  /// Request ids of offer notifications posted for [orderId].
  List<int> requestIdsForOrder(int orderId) {
    final ids = <int>[];
    for (final entry in _prefs.getStringList(_offerOrdersKey) ?? const []) {
      final parts = entry.split(':');
      if (parts.length != 2 || int.tryParse(parts[1]) != orderId) continue;
      final requestId = int.tryParse(parts[0]);
      if (requestId != null) ids.add(requestId);
    }
    return ids;
  }

  /// Opt-in for the floating bubble. Off until the rider turns it on.
  bool get bubbleEnabled => _prefs.getBool(_bubbleEnabledKey) ?? false;
  Future<void> setBubbleEnabled(bool value) =>
      _prefs.setBool(_bubbleEnabledKey, value);

  /// Whether the rider has seen and accepted the background location
  /// disclosure. Versioned so a material change can ask again.
  bool get disclosureAccepted => _prefs.getBool(_disclosureKey) ?? false;
  Future<void> setDisclosureAccepted() => _prefs.setBool(_disclosureKey, true);

  /// Called on going Offline and on sign-out. The bubble and disclosure
  /// choices are the rider's settings and survive.
  Future<void> clearSessionState() async {
    await _prefs.setBool(_onlineKey, false);
    await _prefs.remove(_activeDeliveryKey);
    await _prefs.remove(_lastUploadKey);
    await _prefs.remove(_alertedKey);
    await _prefs.remove(_offerOrdersKey);
  }
}
