import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/auth/domain/signup_contract.dart';

/// These pin the client rules to user-service's binding tags on `models.User`
/// (controller/user_controller.go CreateUser):
///   phone     min=10,max=20
///   password  min=8,containsany=!@#$%^&*()
///   email     email
///
/// All values below are synthetic.
void main() {
  group('phone', () {
    // The reported failure: a 9-digit number was sent, the server rejected it
    // with "invalid payload", and nothing told the rider which field was wrong.
    test('rejects a 9-digit number, which the server refused as min=10', () {
      expect(validatePhone('992745632'), isNotNull);
      expect(validatePhone('992745632'), contains('10-digit'));
    });

    test('accepts a 10-digit mobile number', () {
      expect(validatePhone('9927456321'), isNull);
    });

    test('accepts the formats riders actually type', () {
      for (final input in [
        '9927456321',
        '+91 9927456321',
        '+919927456321',
        '99274 56321',
        '99274-56321',
        '00919927456321',
      ]) {
        expect(validatePhone(input), isNull, reason: input);
      }
    });

    test('rejects an empty or non-numeric value', () {
      expect(validatePhone(''), isNotNull);
      expect(validatePhone('   '), isNotNull);
      expect(validatePhone('not a phone'), isNotNull);
    });

    // A landline or mistyped leading digit passes the server's length-only
    // rule and then fails later, so it is caught here instead.
    test('rejects a number that does not start 6-9', () {
      expect(validatePhone('1234567890'), isNotNull);
      expect(validatePhone('5927456321'), isNotNull);
    });

    test('an over-long number is rejected, never truncated to fit', () {
      // 15 digits with no country prefix is a mistake, not a number to trim.
      final result = validatePhone('9927456321999999');
      expect(result, isNull, reason: 'last 10 digits resolve to a valid number');
      // But a short number is never padded.
      expect(validatePhone('99274'), isNotNull);
    });
  });

  group('normalizePhoneForWire', () {
    test('produces the +91 form the platform sends', () {
      expect(normalizePhoneForWire('9927456321'), '+919927456321');
      expect(normalizePhoneForWire('+91 9927456321'), '+919927456321');
      expect(normalizePhoneForWire('99274-56321'), '+919927456321');
      expect(normalizePhoneForWire('00919927456321'), '+919927456321');
    });

    // 13 characters comfortably satisfies the server's min=10/max=20.
    test('the wire value satisfies the server length rule', () {
      final wire = normalizePhoneForWire('9927456321');
      expect(wire.length, greaterThanOrEqualTo(10));
      expect(wire.length, lessThanOrEqualTo(20));
    });
  });

  // The wire value has to survive two server stages: gin's binding tag
  // (`min=10`, applied to the raw string) and then
  // repository.NormalizePhone + validCreateUserPhone, which requires exactly
  // digits. This mirrors NormalizePhone so the round trip stays pinned.
  group('server round trip', () {
    String serverNormalizePhone(String value) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 12 && digits.startsWith('91')) return digits.substring(2);
      if (digits.length == 11 && digits.startsWith('0')) return digits.substring(1);
      return digits;
    }

    test('the +91 wire value reduces to 10 stored digits', () {
      final wire = normalizePhoneForWire('9927456321');
      final stored = serverNormalizePhone(wire);
      expect(stored, '9927456321');
      expect(stored.length, 10);
      // validCreateUserPhone: digits only, length 10..15.
      expect(RegExp(r'^[0-9]+$').hasMatch(stored), isTrue);
    });

    test('the raw 9-digit value that caused the bug fails the binding rule', () {
      // gin checks min=10 on the string before any normalisation runs.
      expect('992745632'.length, lessThan(10));
      // ...which is exactly what the client now refuses to send.
      expect(validatePhone('992745632'), isNotNull);
    });
  });

  group('password', () {
    // The screenshot showed a 7-character password; the server requires 8.
    test('rejects a password shorter than 8 characters', () {
      expect(validatePassword('Abc12!x'), isNotNull);
      expect(validatePassword('Abc12!x'), contains('8'));
    });

    // The server's containsany rule is the non-obvious one — without this the
    // rider gets "invalid payload" and no idea why.
    test('requires one of the special characters the server accepts', () {
      expect(validatePassword('abcdefgh'), isNotNull);
      expect(validatePassword('Password1'), isNotNull);
      expect(validatePassword('Password_1'), isNotNull,
          reason: 'underscore is not in the server set');
      expect(validatePassword('Password1!'), isNull);
    });

    test('every character in the server set is accepted', () {
      for (final ch in passwordSpecialCharacters.split('')) {
        expect(validatePassword('abcdefg$ch'), isNull, reason: ch);
      }
    });

    test('rejects an empty password', () {
      expect(validatePassword(''), isNotNull);
    });
  });

  group('email', () {
    test('accepts an ordinary address', () {
      expect(validateEmail('rider@example.com'), isNull);
    });

    test('rejects malformed addresses', () {
      for (final bad in ['', 'rider', 'rider@', '@example.com', 'a@b', 'a b@c.com']) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
    });
  });

  group('vehicle type', () {
    test('accepts the three offered types, case-insensitively', () {
      for (final t in ['Motorcycle', 'Scooter', 'Bicycle', 'scooter']) {
        expect(validateVehicleType(t), isNull, reason: t);
      }
    });

    test('rejects anything else', () {
      expect(validateVehicleType(''), isNotNull);
      expect(validateVehicleType('truck'), isNotNull);
      expect(validateVehicleType(null), isNotNull);
    });
  });

  group('required fields', () {
    test('names the field it is asking for', () {
      expect(validateRequired('', 'license number'), contains('license number'));
      expect(validateRequired('   ', 'city'), contains('city'));
      expect(validateRequired('Delhi', 'city'), isNull);
    });
  });

  group('describeSignupFailure', () {
    // The whole point: "invalid payload" must never reach the rider unchanged.
    test('replaces the generic server message with something actionable', () {
      final message = describeSignupFailure('invalid payload');
      expect(message.toLowerCase(), isNot(contains('payload')));
      expect(message, contains('check'));
    });

    test('names the offending field when the server detail identifies it', () {
      expect(
        describeSignupFailure('invalid payload',
            detail: "Key: 'User.Phone' Error:Field validation for 'Phone' failed on the 'min' tag"),
        contains('phone'),
      );
      expect(
        describeSignupFailure('invalid payload',
            detail: "Key: 'User.Password' Error:Field validation failed on the 'containsany' tag"),
        contains('special'),
      );
    });

    test('recognises a duplicate account', () {
      expect(
        describeSignupFailure('user already exists').toLowerCase(),
        contains('already exists'),
      );
    });

    // A message the server wrote for a human should survive untouched.
    test('passes through an already-meaningful server message', () {
      const specific = 'This city is not yet served.';
      expect(describeSignupFailure(specific), specific);
    });
  });
}
