import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Material 3 theme, built per brightness and per language.
abstract final class AppTheme {
  static const String arabicFont = 'IBMPlexSansArabic';
  static const String latinFont = 'IBMPlexSans';

  /// Digits that keep the same width, so live numbers do not jitter.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(18));
  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(10));

  /// Duration of colour changes driven by the body (zones, quality).
  static const Duration bodyTransition = Duration(milliseconds: 600);

  /// IBM Plex Sans Arabic for Arabic, IBM Plex Sans for English; each falls
  /// back to the other for mixed text.
  static String fontFor(Locale locale) => locale.languageCode == 'ar' ? arabicFont : latinFont;

  static ThemeData build({required Brightness brightness, required Locale locale}) {
    final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    final font = fontFor(locale);
    final fallback = [if (font == arabicFont) latinFont else arabicFont];

    final scheme = ColorScheme.fromSeed(
      seedColor: p.oxy,
      brightness: brightness,
      surface: p.sheet,
      onSurface: p.ink,
      primary: p.ink,
      onPrimary: p.sheet,
      secondary: p.oxy,
      error: p.pulse,
      outline: p.rule,
      outlineVariant: p.rule,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      fontFamilyFallback: fallback,
      scaffoldBackgroundColor: p.paper,
      extensions: [p],
    );
    final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
    final buttonText = TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 24),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        bodySmall: text.bodySmall?.copyWith(color: p.muted, fontSize: 12.5, height: 1.45),
        labelMedium: text.labelMedium?.copyWith(color: p.muted, fontSize: 13),
      ),
      cardTheme: CardTheme(
        color: p.sheet,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: cardRadius, side: BorderSide(color: p.rule)),
      ),
      dividerTheme: DividerThemeData(color: p.rule, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.sheet,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.rule),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w400, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.ink, textStyle: buttonText),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.ink,
          selectedForegroundColor: p.sheet,
          foregroundColor: p.ink,
          side: BorderSide(color: p.rule),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w400, fontSize: 13.5),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.sheet,
        indicatorColor: p.paper,
        selectedIconTheme: IconThemeData(color: p.pulse),
        unselectedIconTheme: IconThemeData(color: p.muted),
        selectedLabelTextStyle: TextStyle(color: p.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
        unselectedLabelTextStyle: TextStyle(color: p.muted, fontSize: 12.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.sheet,
        indicatorColor: p.paper,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.pulse : p.muted),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.ink, borderRadius: controlRadius),
        textStyle: TextStyle(color: p.sheet, fontSize: 12.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(linearTrackColor: p.track),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
