/// Client-side mirror of the rider signup contract enforced by user-service.
///
/// The rules here are deliberately *identical to or stricter than* the server's
/// and never looser. They exist so a rider is told which field is wrong before
/// submitting, instead of receiving the server's single generic
/// "invalid payload" response for any violation.
///
/// Server contract (user-service `models.User`, bound by `ShouldBindJSON` in
/// controller/user_controller.go CreateUser). Only three fields carry binding
/// tags:
///
///   email     `binding:"omitempty,email"`
///   phone     `binding:"omitempty,min=10,max=20"`
///   password  `binding:"omitempty,min=8,containsany=!@#$%^&*()"`
///
/// Note `min=10` counts *characters of the string*, so "+919927456" would
/// satisfy the server with only seven national digits. This client requires ten
/// national digits, which is the real-world rule — stricter, never looser.
library;

/// The characters user-service accepts for `containsany`. Kept as a literal
/// set so it cannot drift from the server tag by accident.
const String passwordSpecialCharacters = r'!@#$%^&*()';

/// Minimum password length, matching `min=8`.
const int passwordMinLength = 8;

/// Vehicle types the signup form offers. Sent lower-cased.
const List<String> supportedVehicleTypes = <String>[
  'motorcycle',
  'scooter',
  'bicycle',
];

/// Default dialling code. Matches the convention already used by the
/// restaurant-owner signup, which sends `phone_country_code: '+91'` and a
/// `+91`-prefixed phone.
const String defaultPhoneCountryCode = '+91';

/// Digits of a national Indian mobile number.
const int nationalPhoneDigits = 10;

// ─── Validators ──────────────────────────────────────────────────────────────
// Each returns null when valid, or a message written for the rider.

String? validateRequired(String? value, String fieldLabel) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter your $fieldLabel';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address';
  // Deliberately permissive, like the server's `email` rule: reject what is
  // obviously not an address rather than trying to out-guess RFC 5322.
  final looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');
  if (!looksLikeEmail.hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Validates a phone number by its digits, so spaces, dashes and a leading
/// `+91` typed by the rider are all accepted.
///
/// The number is never padded or truncated to make it fit — an eight-digit
/// number is reported as wrong, not silently completed.
String? validatePhone(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'Enter your phone number';

  final digits = _digitsOnly(raw);
  if (digits.isEmpty) return 'Enter your phone number';

  final national = _nationalDigits(digits);
  if (national.length != nationalPhoneDigits) {
    return 'Enter a $nationalPhoneDigits-digit phone number';
  }
  // Indian mobile numbers start 6-9. A landline or a mistyped number would be
  // accepted by the server's length-only rule and then fail at OTP time.
  if (!RegExp(r'^[6-9]').hasMatch(national)) {
    return 'Enter a valid mobile number';
  }
  return null;
}

/// Mirrors `min=8,containsany=!@#$%^&*()`.
///
/// The special-character requirement is the server's, not an invention: without
/// it the request is rejected with no indication of which rule failed.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Choose a password';
  if (password.length < passwordMinLength) {
    return 'Use at least $passwordMinLength characters';
  }
  final hasSpecial = password.split('').any(
    passwordSpecialCharacters.contains,
  );
  if (!hasSpecial) {
    return 'Add one special character: $passwordSpecialCharacters';
  }
  return null;
}

String? validateVehicleType(String? value) {
  final vehicle = value?.trim().toLowerCase() ?? '';
  if (!supportedVehicleTypes.contains(vehicle)) {
    return 'Choose your vehicle type';
  }
  return null;
}

// ─── Normalisation ───────────────────────────────────────────────────────────

/// Converts a validated phone number into the wire format the platform uses:
/// `+91` followed by the ten national digits.
///
/// Only call this on a value that passed [validatePhone]; it normalises shape,
/// it does not repair an invalid number.
String normalizePhoneForWire(
  String value, {
  String countryCode = defaultPhoneCountryCode,
}) {
  final national = _nationalDigits(_digitsOnly(value));
  return '$countryCode$national';
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Strips a leading country code so "+91 99274 56321", "9199274 56321" and
/// "9927456321" all reduce to the same ten national digits.
String _nationalDigits(String digits) {
  if (digits.length > nationalPhoneDigits &&
      digits.startsWith('91') &&
      digits.length == nationalPhoneDigits + 2) {
    return digits.substring(2);
  }
  if (digits.length > nationalPhoneDigits) {
    // A longer string keeps its last ten digits, which is how an
    // international prefix such as 0091 resolves.
    return digits.substring(digits.length - nationalPhoneDigits);
  }
  return digits;
}

// ─── Server error mapping ────────────────────────────────────────────────────

/// Turns user-service's generic bind failure into something a rider can act on.
///
/// `CreateUser` answers every binding violation with the single message
/// "invalid payload" plus the raw validator detail, which names the Go struct
/// field and tag. This maps the detail back to the field the rider actually
/// filled in, and falls back to the server's own message when it is already
/// meaningful.
String describeSignupFailure(String serverMessage, {String? detail}) {
  final haystack = '$serverMessage ${detail ?? ''}'.toLowerCase();

  if (haystack.contains('phone')) {
    return 'That phone number is not valid. Enter a $nationalPhoneDigits-digit mobile number.';
  }
  if (haystack.contains('password')) {
    return 'That password does not meet the requirements: at least '
        '$passwordMinLength characters, including one special character '
        'from $passwordSpecialCharacters';
  }
  if (haystack.contains('email')) {
    return 'That email address is not valid.';
  }
  if (haystack.contains('already') ||
      haystack.contains('exists') ||
      haystack.contains('duplicate')) {
    return 'An account already exists with these details. Try signing in instead.';
  }
  if (serverMessage.trim().isEmpty ||
      serverMessage.toLowerCase() == 'invalid payload') {
    return 'Some details are not valid. Please check the highlighted fields.';
  }
  return serverMessage;
}
