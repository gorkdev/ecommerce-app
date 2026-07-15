import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// "Soft modern": pastel surfaces, pill shapes, ink text, one shadow recipe.
/// Every value here comes from the design spec; screens read the extras
/// through [AppTokens] instead of hardcoding colors or radii.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final AppTokens tokens = isLight ? AppTokens.light : AppTokens.dark;

    final ColorScheme scheme = isLight
        ? const ColorScheme.light(
            primary: Color(0xFF6C63FF),
            onPrimary: Colors.white,
            primaryContainer: Color(0xFFE4E1FF),
            onPrimaryContainer: Color(0xFF2A2565),
            secondary: Color(0xFF3EBD93),
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFFD8F5EA),
            onSecondaryContainer: Color(0xFF115C42),
            tertiary: Color(0xFFFF8A65),
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFFFE4D8),
            onTertiaryContainer: Color(0xFF7A3014),
            error: Color(0xFFE5484D),
            onError: Colors.white,
            errorContainer: Color(0xFFFDE3E4),
            onErrorContainer: Color(0xFF7F1D20),
            surface: Colors.white,
            onSurface: Color(0xFF1B1B23),
            surfaceContainerHighest: Color(0xFFF1EEF9),
            onSurfaceVariant: Color(0xFF6E6A7C),
            outline: Color(0xFFD9D5E4),
          )
        : const ColorScheme.dark(
            primary: Color(0xFF8B84FF),
            onPrimary: Color(0xFF201B55),
            primaryContainer: Color(0xFF322D6B),
            onPrimaryContainer: Color(0xFFE4E1FF),
            secondary: Color(0xFF5AD4A8),
            onSecondary: Color(0xFF0B3D2C),
            secondaryContainer: Color(0xFF14453A),
            onSecondaryContainer: Color(0xFFD8F5EA),
            tertiary: Color(0xFFFF9E7D),
            onTertiary: Color(0xFF521E0A),
            tertiaryContainer: Color(0xFF6B2E14),
            onTertiaryContainer: Color(0xFFFFE4D8),
            error: Color(0xFFFF7A7F),
            onError: Color(0xFF4A0F12),
            errorContainer: Color(0xFF5C2325),
            onErrorContainer: Color(0xFFFDE3E4),
            surface: Color(0xFF1C1B26),
            onSurface: Color(0xFFF2F0FA),
            surfaceContainerHighest: Color(0xFF262433),
            onSurfaceVariant: Color(0xFFA7A3B8),
            outline: Color(0xFF3E3B4A),
          );

    final Color background =
        isLight ? const Color(0xFFF7F5FB) : const Color(0xFF14131C);

    const String font = 'PlusJakartaSans';
    final TextTheme text = ThemeData(brightness: brightness)
        .textTheme
        .apply(
          fontFamily: font,
          bodyColor: tokens.ink,
          displayColor: tokens.ink,
        )
        .copyWith(
          displaySmall: TextStyle(
            fontFamily: font,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: tokens.ink,
            height: 1.15,
          ),
          headlineMedium: TextStyle(
            fontFamily: font,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: tokens.ink,
            height: 1.2,
          ),
          titleLarge: TextStyle(
            fontFamily: font,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tokens.ink,
          ),
          titleMedium: TextStyle(
            fontFamily: font,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.ink,
          ),
          titleSmall: TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
          bodyLarge: TextStyle(
            fontFamily: font,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: tokens.ink,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: tokens.ink,
            height: 1.45,
          ),
          bodySmall: TextStyle(
            fontFamily: font,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: tokens.inkMuted,
          ),
          labelLarge: TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
          labelMedium: TextStyle(
            fontFamily: font,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: tokens.ink,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelMedium,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: font,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: font,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: text.bodyMedium!.copyWith(color: tokens.inkMuted),
        labelStyle: text.bodyMedium!.copyWith(color: tokens.inkMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(text.labelMedium!),
        iconTheme: WidgetStatePropertyAll<IconThemeData>(
          IconThemeData(color: tokens.ink),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isLight ? tokens.ink : scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 14,
          color: isLight ? Colors.white : tokens.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusLg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
    );
  }
}
