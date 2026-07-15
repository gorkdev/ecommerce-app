import 'package:flutter/material.dart';

/// A pastel background with its guaranteed-readable foreground.
@immutable
class PastelPair {
  const PastelPair({required this.container, required this.onContainer});

  final Color container;
  final Color onContainer;

  static PastelPair lerp(PastelPair a, PastelPair b, double t) => PastelPair(
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );
}

/// Design tokens the ColorScheme cannot express. Spacing and radii are
/// brightness-independent statics; colors come in light/dark instances.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ink,
    required this.inkMuted,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.amber,
    required this.periwinkle,
    required this.violet,
    required this.cyan,
    required this.mint,
    required this.neutral,
    required this.rose,
    required this.cardShadow,
  });

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 32;

  static const double radiusXs = 10;
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 24;

  static const EdgeInsets screenPadding = EdgeInsets.all(20);

  final Color ink;
  final Color inkMuted;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final PastelPair amber;
  final PastelPair periwinkle;
  final PastelPair violet;
  final PastelPair cyan;
  final PastelPair mint;
  final PastelPair neutral;
  final PastelPair rose;
  final List<BoxShadow> cardShadow;

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  static const AppTokens light = AppTokens(
    ink: Color(0xFF1B1B23),
    inkMuted: Color(0xFF6E6A7C),
    warning: Color(0xFFF0A430),
    warningContainer: Color(0xFFFDEFD3),
    onWarningContainer: Color(0xFF6B4A0E),
    amber: PastelPair(
      container: Color(0xFFFDEFD3),
      onContainer: Color(0xFF6B4A0E),
    ),
    periwinkle: PastelPair(
      container: Color(0xFFE3ECFF),
      onContainer: Color(0xFF2B4A8F),
    ),
    violet: PastelPair(
      container: Color(0xFFE4E1FF),
      onContainer: Color(0xFF2A2565),
    ),
    cyan: PastelPair(
      container: Color(0xFFD7F2F8),
      onContainer: Color(0xFF115E70),
    ),
    mint: PastelPair(
      container: Color(0xFFD8F5EA),
      onContainer: Color(0xFF115C42),
    ),
    neutral: PastelPair(
      container: Color(0xFFECEAF1),
      onContainer: Color(0xFF55515F),
    ),
    rose: PastelPair(
      container: Color(0xFFFCE1E8),
      onContainer: Color(0xFF8C2743),
    ),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x146C63FF),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );

  static const AppTokens dark = AppTokens(
    ink: Color(0xFFF2F0FA),
    inkMuted: Color(0xFFA7A3B8),
    warning: Color(0xFFF5B65A),
    warningContainer: Color(0xFF4A3A17),
    onWarningContainer: Color(0xFFFDEFD3),
    amber: PastelPair(
      container: Color(0xFF4A3A17),
      onContainer: Color(0xFFFDEFD3),
    ),
    periwinkle: PastelPair(
      container: Color(0xFF25355C),
      onContainer: Color(0xFFE3ECFF),
    ),
    violet: PastelPair(
      container: Color(0xFF322D6B),
      onContainer: Color(0xFFE4E1FF),
    ),
    cyan: PastelPair(
      container: Color(0xFF143E4A),
      onContainer: Color(0xFFD7F2F8),
    ),
    mint: PastelPair(
      container: Color(0xFF14453A),
      onContainer: Color(0xFFD8F5EA),
    ),
    neutral: PastelPair(
      container: Color(0xFF3A3745),
      onContainer: Color(0xFFECEAF1),
    ),
    rose: PastelPair(
      container: Color(0xFF5C2333),
      onContainer: Color(0xFFFCE1E8),
    ),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x4D000000),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      amber: PastelPair.lerp(amber, other.amber, t),
      periwinkle: PastelPair.lerp(periwinkle, other.periwinkle, t),
      violet: PastelPair.lerp(violet, other.violet, t),
      cyan: PastelPair.lerp(cyan, other.cyan, t),
      mint: PastelPair.lerp(mint, other.mint, t),
      neutral: PastelPair.lerp(neutral, other.neutral, t),
      rose: PastelPair.lerp(rose, other.rose, t),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}
