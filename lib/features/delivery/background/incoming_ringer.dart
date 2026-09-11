import 'dart:async';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Plays and stops the ringtone. Abstracted so the stop rules can be tested.
abstract class RingtoneOutput {
  Future<void> start();
  Future<void> stop();
}

class SystemRingtoneOutput implements RingtoneOutput {
  @override
  Future<void> start() => FlutterRingtonePlayer().playRingtone(looping: true);

  @override
  Future<void> stop() => FlutterRingtonePlayer().stop();
}

/// The in-app ring for a delivery request while the app is on screen.
///
/// It loops like a call so a rider glancing away still hears it, but it is
/// always bounded: it stops at the offer's expiry or [maxRing], whichever is
/// sooner, and earlier when the controller calls [stop] — on accept, decline,
/// another rider taking the order, going Offline, sign-out, or the app
/// leaving the screen (where the service's notification takes over).
class IncomingRinger {
  IncomingRinger(
    this._output, {
    this.maxRing = const Duration(seconds: 45),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RingtoneOutput _output;
  final Duration maxRing;
  final DateTime Function() _clock;

  Timer? _stopTimer;
  bool _ringing = false;

  bool get isRinging => _ringing;

  /// Rings until [until]. A second call while ringing extends the stop time
  /// to the later offer without restarting the sound.
  Future<void> ring({required DateTime until}) async {
    var remaining = until.toUtc().difference(_clock().toUtc());
    if (remaining > maxRing) {
      remaining = maxRing;
    }
    if (remaining <= Duration.zero) {
      return;
    }
    _stopTimer?.cancel();
    _stopTimer = Timer(remaining, () => unawaited(stop()));
    if (_ringing) {
      return;
    }
    _ringing = true;
    await _output.start();
  }

  Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    if (!_ringing) {
      return;
    }
    _ringing = false;
    await _output.stop();
  }
}
