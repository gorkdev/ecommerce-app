import 'package:ecommerce_app/shared/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('accepts a well-formed address', () {
      expect(Validators.email('customer@example.com'), isNull);
    });

    test('trims before validating', () {
      expect(Validators.email('  customer@example.com  '), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.email(''), 'Enter your email address.');
      expect(Validators.email(null), 'Enter your email address.');
      expect(Validators.email('   '), 'Enter your email address.');
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
          Validators.email(input),
          'Enter a valid email address.',
          reason: '"$input" should be rejected',
        );
      }
    });
  });

  group('Validators.password', () {
    test('mirrors the server DTO bounds of 8..72 characters', () {
      expect(Validators.password('a' * 7), 'Use at least 8 characters.');
      expect(Validators.password('a' * 8), isNull);
      expect(Validators.password('a' * 72), isNull);
      expect(Validators.password('a' * 73), 'Use at most 72 characters.');
    });

    test('rejects empty input', () {
      expect(Validators.password(''), 'Enter a password.');
      expect(Validators.password(null), 'Enter a password.');
    });

    test('does not trim — spaces are legal password characters', () {
      expect(Validators.password('  pass  '), isNull);
    });
  });

  group('Validators.loginPassword', () {
    test('only requires a non-empty value', () {
      expect(Validators.loginPassword('short'), isNull);
      expect(Validators.loginPassword(''), 'Enter your password.');
      expect(Validators.loginPassword(null), 'Enter your password.');
    });
  });

  group('Validators.name', () {
    test('mirrors the server DTO bounds of 2..80 characters', () {
      expect(Validators.name('a'), 'Use at least 2 characters.');
      expect(Validators.name('ab'), isNull);
      expect(Validators.name('a' * 80), isNull);
      expect(Validators.name('a' * 81), 'Use at most 80 characters.');
    });

    test('rejects blank input', () {
      expect(Validators.name('   '), 'Enter your name.');
      expect(Validators.name(null), 'Enter your name.');
    });
  });
}
