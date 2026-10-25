import 'package:flutter/material.dart';

/// Colours of the app, in a light and a dark variant.
///
/// The light palette comes from the prototype dashboard: calm clinical paper,
/// one strong pulse red and a teal for oxygen. The four heart-rate zone
/// colours follow a cool-to-warm scale so a change is felt before it is read.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.paper,
    required this.sheet,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.track,
    required this.pulse,
    required this.oxy,
    required this.warn,
    required this.ok,
    required this.idle,
    required this.noticeBg,
    required this.noticeBorder,
    required this.noticeText,
    required this.gridMinor,
    required this.gridMajor,
    required this.zoneLow,
    required this.zoneNormal,
    required this.zoneElevated,
    required this.zoneHigh,
    required this.shadow,
  });

  static const AppPalette light = AppPalette(
    paper: Color(0xFFEEF2F3),
    sheet: Color(0xFFFFFFFF),
    ink: Color(0xFF16232A),
    muted: Color(0xFF5D6D75),
    rule: Color(0xFFDCE3E6),
    track: Color(0xFFE2E8EA),
    pulse: Color(0xFFC3122E),
    oxy: Color(0xFF1D6474),
    warn: Color(0xFF9A5B00),
    ok: Color(0xFF2E8B57),
    idle: Color(0xFF9AA8AE),
    noticeBg: Color(0xFFFFF4E0),
    noticeBorder: Color(0xFFF0D3A2),
    noticeText: Color(0xFF5C3A00),
    gridMinor: Color(0x12C3122E),
    gridMajor: Color(0x29C3122E),
    zoneLow: Color(0xFF2F6FB5),
    zoneNormal: Color(0xFF0F8A70),
    zoneElevated: Color(0xFFC27400),
    zoneHigh: Color(0xFFC3122E),
    shadow: Color(0x14102A33),
  );

  static const AppPalette dark = AppPalette(
    paper: Color(0xFF0D1417),
    sheet: Color(0xFF151F23),
    ink: Color(0xFFE5ECEE),
    muted: Color(0xFF93A4AB),
    rule: Color(0xFF27353B),
    track: Color(0xFF223036),
    pulse: Color(0xFFFF5D70),
    oxy: Color(0xFF55B6C7),
    warn: Color(0xFFE3A64A),
    ok: Color(0xFF4CC48A),
    idle: Color(0xFF5F7179),
    noticeBg: Color(0xFF2D2310),
    noticeBorder: Color(0xFF5A4520),
    noticeText: Color(0xFFF2D9A8),
    gridMinor: Color(0x14FF5D70),
    gridMajor: Color(0x2EFF5D70),
    zoneLow: Color(0xFF6EA8F0),
    zoneNormal: Color(0xFF3CC6A2),
    zoneElevated: Color(0xFFF0B03A),
    zoneHigh: Color(0xFFFF5D70),
    shadow: Color(0x66000000),
  );

  /// Page background.
  final Color paper;

  /// Card background.
  final Color sheet;

  /// Main text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Borders and dividers.
  final Color rule;

  /// Empty part of progress bars and rings.
  final Color track;

  /// Recording, errors, weak quality.
  final Color pulse;

  /// SpO2 and excellent quality.
  final Color oxy;

  /// Warnings and acceptable quality.
  final Color warn;

  /// Connected state.
  final Color ok;

  /// Disconnected state.
  final Color idle;

  final Color noticeBg;
  final Color noticeBorder;
  final Color noticeText;

  /// ECG paper grid.
  final Color gridMinor;
  final Color gridMajor;

  /// Heart-rate zones at rest.
  final Color zoneLow;
  final Color zoneNormal;
  final Color zoneElevated;
  final Color zoneHigh;

  /// Card shadow.
  final Color shadow;

  /// Soft shadow used by cards.
  List<BoxShadow> get cardShadow => [
        BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
      ];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      paper: l(paper, other.paper),
      sheet: l(sheet, other.sheet),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      rule: l(rule, other.rule),
      track: l(track, other.track),
      pulse: l(pulse, other.pulse),
      oxy: l(oxy, other.oxy),
      warn: l(warn, other.warn),
      ok: l(ok, other.ok),
      idle: l(idle, other.idle),
      noticeBg: l(noticeBg, other.noticeBg),
      noticeBorder: l(noticeBorder, other.noticeBorder),
      noticeText: l(noticeText, other.noticeText),
      gridMinor: l(gridMinor, other.gridMinor),
      gridMajor: l(gridMajor, other.gridMajor),
      zoneLow: l(zoneLow, other.zoneLow),
      zoneNormal: l(zoneNormal, other.zoneNormal),
      zoneElevated: l(zoneElevated, other.zoneElevated),
      zoneHigh: l(zoneHigh, other.zoneHigh),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
