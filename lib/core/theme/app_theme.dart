import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';

/// Premium SaaS-grade design tokens.
///
/// Inspired by Linear / Notion / Vercel: deep neutral surfaces, restrained
/// accents, subtle borders instead of shadows, tight rhythm.
abstract final class AppPalette {
  // Light surfaces — warm neutral, not pure white.
  static const Color lightBackground = Color(0xFFFAFAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF5F5F4);
  static const Color lightSurfaceSubtle = Color(0xFFFAFAF9);
  static const Color lightBorder = Color(0xFFE7E5E4);
  static const Color lightBorderStrong = Color(0xFFD6D3D1);
  static const Color lightTextPrimary = Color(0xFF1C1917);
  static const Color lightTextSecondary = Color(0xFF57534E);
  static const Color lightTextTertiary = Color(0xFFA8A29E);

  // Dark surfaces — deep neutral, never pure black.
  static const Color darkBackground = Color(0xFF0A0A0B);
  static const Color darkSurface = Color(0xFF131316);
  static const Color darkSurfaceMuted = Color(0xFF1A1A1F);
  static const Color darkSurfaceSubtle = Color(0xFF101013);
  static const Color darkBorder = Color(0x1AFFFFFF); // ~10% white
  static const Color darkBorderStrong = Color(0x26FFFFFF); // ~15% white
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xB3FFFFFF); // 70%
  static const Color darkTextTertiary = Color(0x80FFFFFF); // 50%

  // Accent — single restrained indigo used sparingly for primary actions.
  static const Color brandLight = Color(0xFF5B5BD6);
  static const Color brandDark = Color(0xFF7B7BE3);

  // Semantic tones (kept muted, never neon).
  static const Color successLight = Color(0xFF15803D);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warningLight = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerLight = Color(0xFFB91C1C);
  static const Color dangerDark = Color(0xFFF87171);
}

/// Standardized radii (12 across components, 10 for compact, 999 for pills).
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;
}

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 240);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark ? _darkScheme : _lightScheme;
    final background = isDark ? AppPalette.darkBackground : AppPalette.lightBackground;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final textPrimary = isDark ? AppPalette.darkTextPrimary : AppPalette.lightTextPrimary;
    final textSecondary = isDark ? AppPalette.darkTextSecondary : AppPalette.lightTextSecondary;
    final textTertiary = isDark ? AppPalette.darkTextTertiary : AppPalette.lightTextTertiary;
    final surface = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final surfaceMuted = isDark ? AppPalette.darkSurfaceMuted : AppPalette.lightSurfaceMuted;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = _buildTextTheme(base.textTheme, textPrimary, textSecondary);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(size: 18, color: textSecondary),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppPalette.darkSurfaceMuted : AppPalette.lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AppPalette.darkTextPrimary : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.primary.withValues(alpha: 0.4);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withValues(alpha: 0.92);
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimary),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          animationDuration: AppDuration.base,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(textPrimary),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return surfaceMuted;
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: border.withValues(alpha: 0.5));
            }
            return BorderSide(color: border);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          animationDuration: AppDuration.base,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(textPrimary),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return surfaceMuted;
            }
            return null;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(textSecondary),
          minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return surfaceMuted;
            return null;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppPalette.darkSurfaceMuted : AppPalette.lightSurface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: textTertiary,
        suffixIconColor: textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppPalette.darkBorderStrong : AppPalette.lightBorderStrong,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        side: BorderSide(color: border),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: border),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return surfaceMuted;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return textPrimary;
            return textSecondary;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: surfaceMuted,
        circularTrackColor: surfaceMuted,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkSurfaceMuted : AppPalette.lightTextPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? AppPalette.darkTextPrimary : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColors(
          background: background,
          surface: surface,
          surfaceMuted: surfaceMuted,
          surfaceSubtle: isDark ? AppPalette.darkSurfaceSubtle : AppPalette.lightSurfaceSubtle,
          border: border,
          borderStrong: isDark ? AppPalette.darkBorderStrong : AppPalette.lightBorderStrong,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textTertiary: textTertiary,
          success: isDark ? AppPalette.successDark : AppPalette.successLight,
          warning: isDark ? AppPalette.warningDark : AppPalette.warningLight,
          danger: isDark ? AppPalette.dangerDark : AppPalette.dangerLight,
        ),
      ],
    );
  }

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.brandLight,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFEEF0FB),
    onPrimaryContainer: AppPalette.brandLight,
    secondary: AppPalette.lightTextPrimary,
    onSecondary: Colors.white,
    secondaryContainer: AppPalette.lightSurfaceMuted,
    onSecondaryContainer: AppPalette.lightTextPrimary,
    tertiary: AppPalette.successLight,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE6F4EA),
    onTertiaryContainer: AppPalette.successLight,
    error: AppPalette.dangerLight,
    onError: Colors.white,
    errorContainer: Color(0xFFFDECEC),
    onErrorContainer: AppPalette.dangerLight,
    surface: AppPalette.lightSurface,
    onSurface: AppPalette.lightTextPrimary,
    surfaceContainerLowest: AppPalette.lightSurface,
    surfaceContainerLow: AppPalette.lightSurface,
    surfaceContainer: AppPalette.lightSurfaceMuted,
    surfaceContainerHigh: AppPalette.lightSurfaceMuted,
    surfaceContainerHighest: AppPalette.lightSurfaceMuted,
    onSurfaceVariant: AppPalette.lightTextSecondary,
    outline: AppPalette.lightBorderStrong,
    outlineVariant: AppPalette.lightBorder,
    inverseSurface: AppPalette.lightTextPrimary,
    onInverseSurface: AppPalette.lightSurface,
    inversePrimary: AppPalette.brandDark,
    shadow: Color(0x14000000),
    scrim: Color(0x99000000),
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.brandDark,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF2A2A4A),
    onPrimaryContainer: AppPalette.brandDark,
    secondary: AppPalette.darkTextPrimary,
    onSecondary: AppPalette.darkBackground,
    secondaryContainer: AppPalette.darkSurfaceMuted,
    onSecondaryContainer: AppPalette.darkTextPrimary,
    tertiary: AppPalette.successDark,
    onTertiary: AppPalette.darkBackground,
    tertiaryContainer: Color(0xFF1A3325),
    onTertiaryContainer: AppPalette.successDark,
    error: AppPalette.dangerDark,
    onError: AppPalette.darkBackground,
    errorContainer: Color(0xFF3B1A1A),
    onErrorContainer: AppPalette.dangerDark,
    surface: AppPalette.darkSurface,
    onSurface: AppPalette.darkTextPrimary,
    surfaceContainerLowest: AppPalette.darkSurfaceSubtle,
    surfaceContainerLow: AppPalette.darkSurface,
    surfaceContainer: AppPalette.darkSurfaceMuted,
    surfaceContainerHigh: AppPalette.darkSurfaceMuted,
    surfaceContainerHighest: Color(0xFF22222A),
    onSurfaceVariant: AppPalette.darkTextSecondary,
    outline: AppPalette.darkBorderStrong,
    outlineVariant: AppPalette.darkBorder,
    inverseSurface: AppPalette.darkTextPrimary,
    onInverseSurface: AppPalette.darkBackground,
    inversePrimary: AppPalette.brandLight,
    shadow: Color(0x33000000),
    scrim: Color(0xB3000000),
    surfaceTint: Colors.transparent,
  );

  static TextTheme _buildTextTheme(
    TextTheme base,
    Color primary,
    Color secondary,
  ) {
    final inter = GoogleFonts.interTextTheme(base);
    TextStyle apply(TextStyle? style, {
      double? size,
      FontWeight? weight,
      double? letter,
      double? height,
      Color? color,
    }) {
      return (style ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letter,
        height: height,
        color: color ?? primary,
      );
    }

    return inter.copyWith(
      displayLarge: apply(inter.displayLarge, size: 56, weight: FontWeight.w700, letter: -1.5, height: 1.05),
      displayMedium: apply(inter.displayMedium, size: 44, weight: FontWeight.w700, letter: -1.2, height: 1.08),
      displaySmall: apply(inter.displaySmall, size: 36, weight: FontWeight.w700, letter: -0.9, height: 1.1),
      headlineLarge: apply(inter.headlineLarge, size: 30, weight: FontWeight.w700, letter: -0.6, height: 1.15),
      headlineMedium: apply(inter.headlineMedium, size: 24, weight: FontWeight.w600, letter: -0.4, height: 1.2),
      headlineSmall: apply(inter.headlineSmall, size: 20, weight: FontWeight.w600, letter: -0.3, height: 1.25),
      titleLarge: apply(inter.titleLarge, size: 18, weight: FontWeight.w600, letter: -0.2, height: 1.3),
      titleMedium: apply(inter.titleMedium, size: 16, weight: FontWeight.w600, letter: -0.15, height: 1.35),
      titleSmall: apply(inter.titleSmall, size: 14, weight: FontWeight.w600, letter: -0.05, height: 1.4),
      bodyLarge: apply(inter.bodyLarge, size: 16, weight: FontWeight.w400, letter: -0.1, height: 1.55),
      bodyMedium: apply(inter.bodyMedium, size: 14, weight: FontWeight.w400, letter: 0, height: 1.5, color: secondary),
      bodySmall: apply(inter.bodySmall, size: 13, weight: FontWeight.w400, letter: 0, height: 1.45, color: secondary),
      labelLarge: apply(inter.labelLarge, size: 14, weight: FontWeight.w500, letter: -0.05, height: 1.3),
      labelMedium: apply(inter.labelMedium, size: 12, weight: FontWeight.w500, letter: 0, height: 1.3, color: secondary),
      labelSmall: apply(inter.labelSmall, size: 11, weight: FontWeight.w500, letter: 0.2, height: 1.3, color: secondary),
    );
  }
}

/// Theme extension exposing semantic colors that don't map cleanly onto
/// Material's [ColorScheme] (custom neutrals, semantic tones, etc.).
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSubtle,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSubtle;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color danger;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSubtle,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
