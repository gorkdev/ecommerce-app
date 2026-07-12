import 'dart:ui';

import 'package:ecommerce_app/l10n/generated/app_localizations.dart';
import 'package:ecommerce_app/shared/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The validators only read strings from the localizations, so the English
  // table is enough for the logic; one Turkish probe proves the currying
  // actually respects the locale.
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

  final String? Function(String?) email = Validators.email(en);
  final String? Function(String?) password = Validators.password(en);
  final String? Function(String?) loginPassword = Validators.loginPassword(en);
  final String? Function(String?) name = Validators.name(en);

  group('Validators.email', () {
    test('accepts a well-formed address', () {
      expect(email('customer@example.com'), isNull);
    });

    test('trims before validating', () {
      expect(email('  customer@example.com  '), isNull);
    });

    test('rejects empty input', () {
      expect(email(''), 'Enter your email address.');
      expect(email(null), 'Enter your email address.');
      expect(email('   '), 'Enter your email address.');
    });

    test('rejects malformed addresses', () {
      for (final String input in <String>[
        'customer',
        'customer@',
        '@example.com',
        'customer@example',
        'customer example@test.com',
      ]) {
        expect(
          email(input),
          'Enter a valid email address.',
          reason: '"$input" should be rejected',
        );
      }
    });

    test('speaks the locale it was built with', () {
      expect(Validators.email(tr)(''), 'E-posta adresinizi girin.');
    });
  });

  group('Validators.password', () {
    test('mirrors the server DTO bounds of 8..72 characters', () {
      expect(password('a' * 7), 'Use at least 8 characters.');
      expect(password('a' * 8), isNull);
      expect(password('a' * 72), isNull);
      expect(password('a' * 73), 'Use at most 72 characters.');
    });

    test('rejects empty input', () {
      expect(password(''), 'Enter a password.');
      expect(password(null), 'Enter a password.');
    });

    test('does not trim — spaces are legal password characters', () {
      expect(password('  pass  '), isNull);
    });
  });

  group('Validators.loginPassword', () {
    test('only requires a non-empty value', () {
      expect(loginPassword('short'), isNull);
      expect(loginPassword(''), 'Enter your password.');
      expect(loginPassword(null), 'Enter your password.');
    });
  });

  group('Validators.name', () {
    test('mirrors the server DTO bounds of 2..80 characters', () {
      expect(name('a'), 'Use at least 2 characters.');
      expect(name('ab'), isNull);
      expect(name('a' * 80), isNull);
      expect(name('a' * 81), 'Use at most 80 characters.');
    });

    test('rejects blank input', () {
      expect(name('   '), 'Enter your name.');
      expect(name(null), 'Enter your name.');
    });
  });
}
