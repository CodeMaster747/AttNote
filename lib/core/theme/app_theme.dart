import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final baseTheme = isDark
        ? FlexThemeData.dark(
            colors: const FlexSchemeColor(
              primary: Color(0xFF818CF8),
              primaryContainer: Color(0xFF30398E),
              secondary: Color(0xFF38BDF8),
              secondaryContainer: Color(0xFF1E4E66),
              tertiary: Color(0xFF34D399),
              tertiaryContainer: Color(0xFF205741),
              appBarColor: Color(0xFF121826),
              error: Color(0xFFF87171),
            ),
            useMaterial3: true,
            visualDensity: FlexColorScheme.comfortablePlatformDensity,
            subThemesData: _subThemesData,
          )
        : FlexThemeData.light(
            colors: const FlexSchemeColor(
              primary: Color(0xFF4F46E5),
              primaryContainer: Color(0xFFE0E7FF),
              secondary: Color(0xFF0284C7),
              secondaryContainer: Color(0xFFDFF3FF),
              tertiary: Color(0xFF10B981),
              tertiaryContainer: Color(0xFFD1FAE5),
              appBarColor: Color(0xFFF8FAFC),
              error: Color(0xFFF43F5E),
            ),
            useMaterial3: true,
            visualDensity: FlexColorScheme.comfortablePlatformDensity,
            subThemesData: _subThemesData,
            scaffoldBackground: const Color(0xFFF8FAFC),
          );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme)
        .copyWith(
          titleLarge: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          titleMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        )
        .apply(
      bodyColor: baseTheme.colorScheme.onSurface,
      displayColor: baseTheme.colorScheme.onSurface,
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        },
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: baseTheme.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF30384A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
      ),
      iconTheme: baseTheme.iconTheme.copyWith(
        size: 20,
        color: baseTheme.colorScheme.onSurfaceVariant,
      ),
      listTileTheme: baseTheme.listTileTheme.copyWith(
        iconColor: baseTheme.colorScheme.onSurfaceVariant,
      ),
      snackBarTheme: baseTheme.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
    );
  }

  static const FlexSubThemesData _subThemesData = FlexSubThemesData(
    blendOnLevel: 12,
    blendOnColors: false,
    cardRadius: 16,
    inputDecoratorRadius: 12,
    inputDecoratorIsFilled: true,
    inputDecoratorUnfocusedHasBorder: true,
    inputDecoratorFillColor: Color(0xFFFFFFFF),
    elevatedButtonRadius: 12,
    filledButtonRadius: 12,
    outlinedButtonRadius: 12,
    outlinedButtonOutlineSchemeColor: SchemeColor.outline,
    chipRadius: 10,
    thinBorderWidth: 1.2,
  );
}
