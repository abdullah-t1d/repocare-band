import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opened once in `main` and injected, so reads are synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

/// Choices the user makes once and expects to be remembered.
@immutable
class AppSettings {
  const AppSettings({this.locale = arabic, this.themeMode = ThemeMode.light});

  static const Locale arabic = Locale('ar');
  static const Locale english = Locale('en');
  static const List<Locale> supportedLocales = [arabic, english];

  final Locale locale;

  /// Light or dark; light is the default.
  final ThemeMode themeMode;

  bool get isArabic => locale.languageCode == arabic.languageCode;
  bool get isDark => themeMode == ThemeMode.dark;

  AppSettings copyWith({Locale? locale, ThemeMode? themeMode}) =>
      AppSettings(locale: locale ?? this.locale, themeMode: themeMode ?? this.themeMode);

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.locale == locale && other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(locale, themeMode);
}

/// Language and theme, persisted with shared_preferences.
class SettingsController extends Notifier<AppSettings> {
  static const String localeKey = 'settings.locale';
  static const String themeKey = 'settings.theme';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final code = prefs.getString(localeKey);
    final locale = AppSettings.supportedLocales.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppSettings.arabic,
    );
    final theme = prefs.getString(themeKey) == ThemeMode.dark.name ? ThemeMode.dark : ThemeMode.light;
    return AppSettings(locale: locale, themeMode: theme);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _prefs.setString(localeKey, locale.languageCode);
  }

  Future<void> toggleLanguage() =>
      setLocale(state.isArabic ? AppSettings.english : AppSettings.arabic);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(themeKey, mode.name);
  }

  Future<void> toggleTheme() => setThemeMode(state.isDark ? ThemeMode.light : ThemeMode.dark);
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
