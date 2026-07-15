import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both themes carry AppTokens and the brand font', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      expect(theme.extension<AppTokens>(), isNotNull);
      expect(theme.textTheme.bodyMedium!.fontFamily, 'PlusJakartaSans');
    }
  });

  test('light tokens match the spec palette', () {
    final AppTokens tokens = AppTheme.light.extension<AppTokens>()!;
    expect(tokens.ink, const Color(0xFF1B1B23));
    expect(tokens.mint.container, const Color(0xFFD8F5EA));
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF6C63FF));
  });

  test('every pastel pair keeps readable ink-side contrast', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final AppTokens tokens = theme.extension<AppTokens>()!;
      for (final PastelPair pair in <PastelPair>[
        tokens.amber,
        tokens.periwinkle,
        tokens.violet,
        tokens.cyan,
        tokens.mint,
        tokens.neutral,
        tokens.rose,
      ]) {
        final double bg = pair.container.computeLuminance();
        final double fg = pair.onContainer.computeLuminance();
        final double contrast =
            (bg > fg ? (bg + 0.05) / (fg + 0.05) : (fg + 0.05) / (bg + 0.05));
        // WCAG AA for normal text.
        expect(contrast, greaterThanOrEqualTo(4.5),
            reason: 'pair ${pair.container} on ${pair.onContainer}');
      }
    }
  });
}
