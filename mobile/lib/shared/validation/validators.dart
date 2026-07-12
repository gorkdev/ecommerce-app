import '../../l10n/generated/app_localizations.dart';

/// Client-side mirrors of the server's DTO constraints (`api/src/auth/dto`).
///
/// The API remains the authority — these only spare the user a round-trip.
/// Each factory curries the localizations in, so the result still fits the
/// `FormFieldValidator<String>` shape forms expect.
abstract final class Validators {
  /// Deliberately permissive. Anything stricter rejects valid addresses; the
  /// only real proof an address exists is sending mail to it.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// `@IsEmail()`
  static String? Function(String?) email(AppLocalizations l10n) =>
      (String? value) {
        final String input = value?.trim() ?? '';
        if (input.isEmpty) return l10n.validationEmailRequired;
        if (!_emailPattern.hasMatch(input)) return l10n.validationEmailInvalid;
        return null;
      };

  /// `@MinLength(8) @MaxLength(72)` — 72 bytes is Argon2's practical input cap.
  static String? Function(String?) password(AppLocalizations l10n) =>
      (String? value) {
        final String input = value ?? '';
        if (input.isEmpty) return l10n.validationPasswordRequired;
        if (input.length < 8) return l10n.validationUseAtLeast(8);
        if (input.length > 72) return l10n.validationUseAtMost(72);
        return null;
      };

  /// The login form must not enforce the *registration* rules: an existing
  /// account may predate them, and revealing them helps nobody.
  static String? Function(String?) loginPassword(AppLocalizations l10n) =>
      (String? value) {
        if ((value ?? '').isEmpty) return l10n.validationLoginPasswordRequired;
        return null;
      };

  /// `@MinLength(2) @MaxLength(80)`
  static String? Function(String?) name(AppLocalizations l10n) =>
      (String? value) {
        final String input = value?.trim() ?? '';
        if (input.isEmpty) return l10n.validationNameRequired;
        if (input.length < 2) return l10n.validationUseAtLeast(2);
        if (input.length > 80) return l10n.validationUseAtMost(80);
        return null;
      };
}
