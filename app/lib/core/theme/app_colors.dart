import 'package:flutter/material.dart';

/// Palette taken from the prototype dashboard: a calm clinical paper look
/// with one strong pulse red and a teal for oxygen.
abstract final class AppColors {
  /// Page background.
  static const Color paper = Color(0xFFEEF2F3);

  /// Card and panel background.
  static const Color sheet = Color(0xFFFAFBFB);

  /// Main text.
  static const Color ink = Color(0xFF16232A);

  /// Hover colour for ink buttons.
  static const Color inkHover = Color(0xFF26363F);

  /// Secondary text.
  static const Color muted = Color(0xFF5D6D75);

  /// Borders and dividers.
  static const Color rule = Color(0xFFD3DCDF);

  /// Empty part of a progress bar.
  static const Color track = Color(0xFFE2E8EA);

  /// Heart rate, waveform, recording.
  static const Color pulse = Color(0xFFC3122E);

  /// SpO2 and "excellent" quality.
  static const Color oxy = Color(0xFF1D6474);

  /// Warnings and "acceptable" quality.
  static const Color warn = Color(0xFF9A5B00);

  /// Connected state.
  static const Color ok = Color(0xFF2E8B57);

  /// Disconnected state.
  static const Color idle = Color(0xFF9AA8AE);

  /// Notice box.
  static const Color noticeBg = Color(0xFFFFF4E0);
  static const Color noticeBorder = Color(0xFFF0D3A2);
  static const Color noticeText = Color(0xFF5C3A00);

  /// ECG paper grid.
  static const Color gridMinor = Color(0x12C3122E);
  static const Color gridMajor = Color(0x29C3122E);
}
