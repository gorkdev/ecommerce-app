/// Client-side mirrors of the server's DTO constraints (`api/src/auth/dto`).
///
/// The API remains the authority — these only spare the user a round-trip.
abstract final class Validators {
  /// Deliberately permissive. Anything stricter rejects valid addresses; the
  /// only real proof an address exists is sending mail to it.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// `@IsEmail()`
  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(input)) return 'Enter a valid email address.';
    return null;
  }

  /// `@MinLength(8) @MaxLength(72)` — 72 bytes is Argon2's practical input cap.
  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Enter a password.';
    if (input.length < 8) return 'Use at least 8 characters.';
    if (input.length > 72) return 'Use at most 72 characters.';
    return null;
  }

  /// The login form must not enforce the *registration* rules: an existing
  /// account may predate them, and revealing them helps nobody.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  /// `@MinLength(2) @MaxLength(80)`
  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Enter your name.';
    if (input.length < 2) return 'Use at least 2 characters.';
    if (input.length > 80) return 'Use at most 80 characters.';
    return null;
  }
}
