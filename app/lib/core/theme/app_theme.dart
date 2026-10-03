import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 theme for the app.
abstract final class AppTheme {
  static const String fontFamily = 'IBMPlexSansArabic';

  /// Digits that keep the same width, so live numbers do not jitter.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(8));

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.oxy,
      surface: AppColors.sheet,
      onSurface: AppColors.ink,
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.oxy,
      error: AppColors.pulse,
      outline: AppColors.rule,
      outlineVariant: AppColors.rule,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.paper,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    return base.copyWith(
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        bodySmall: text.bodySmall?.copyWith(color: AppColors.muted, fontSize: 12.5),
        labelMedium: text.labelMedium?.copyWith(color: AppColors.muted, fontSize: 14),
      ),
      cardTheme: const CardTheme(
        color: AppColors.sheet,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: AppColors.rule),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.rule, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.rule),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.ink,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.rule),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.sheet,
        indicatorColor: AppColors.paper,
        selectedIconTheme: IconThemeData(color: AppColors.pulse),
        unselectedIconTheme: IconThemeData(color: AppColors.muted),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.sheet,
        indicatorColor: AppColors.paper,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
