import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/background/incoming_ringer.dart';

import 'background_mode_test_fakes.dart';

void main() {
  late FakeRingtoneOutput output;
  late IncomingRinger ringer;

  setUp(() {
    output = FakeRingtoneOutput();
    ringer = IncomingRinger(output, maxRing: const Duration(milliseconds: 300));
  });

  test('rings for a live offer', () async {
    await ringer.ring(until: DateTime.now().add(const Duration(seconds: 5)));

    expect(output.playing, isTrue);
    expect(ringer.isRinging, isTrue);
  });

  test('never rings for an offer that has already expired', () async {
    await ringer.ring(
      until: DateTime.now().subtract(const Duration(seconds: 1)),
    );

    expect(output.starts, 0);
  });

  test('a second offer while ringing does not restart the sound', () async {
    final until = DateTime.now().add(const Duration(seconds: 5));
    await ringer.ring(until: until);
    await ringer.ring(until: until);

    expect(output.starts, 1);
  });

  // Accept, decline, another rider taking it, Offline, sign-out, app hidden.
  test('stops when told to', () async {
    await ringer.ring(until: DateTime.now().add(const Duration(seconds: 5)));

    await ringer.stop();

    expect(output.playing, isFalse);
    expect(ringer.isRinging, isFalse);
  });

  test('stops by itself at the offer expiry', () async {
    await ringer.ring(
      until: DateTime.now().add(const Duration(milliseconds: 80)),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(output.playing, isFalse);
  });

  test('never rings longer than the cap, even for a long offer', () async {
    await ringer.ring(until: DateTime.now().add(const Duration(minutes: 5)));

    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(output.playing, isFalse);
  });

  test('stopping when silent does nothing', () async {
    await ringer.stop();

    expect(output.stops, 0);
  });
}
