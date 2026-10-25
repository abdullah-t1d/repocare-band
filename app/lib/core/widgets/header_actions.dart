import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// ع / EN switch. The labels are written in their own language on purpose.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  static const Key arabicKey = ValueKey('lang-ar');
  static const Key englishKey = ValueKey('lang-en');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    Widget option(Key key, String label, Locale locale, String font) {
      final selected = settings.locale == locale;
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(999),
          onTap: selected ? null : () => controller.setLocale(locale),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? p.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: font,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? p.sheet : p.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: context.l10n.languageTooltip,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.sheet,
          border: Border.all(color: p.rule),
          borderRadius: BorderRadius.circular(999),
        ),
        // Fixed order (ع then EN) so the control does not jump when the
        // layout direction flips.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(arabicKey, 'ع', AppSettings.arabic, AppTheme.arabicFont),
              option(englishKey, 'EN', AppSettings.english, AppTheme.latinFont),
            ],
          ),
        ),
      ),
    );
  }
}

/// Light / dark switch.
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  static const Key buttonKey = ValueKey('theme-toggle');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(settingsProvider.select((s) => s.isDark));
    final l10n = context.l10n;
    return IconButton(
      key: buttonKey,
      tooltip: dark ? l10n.themeToLight : l10n.themeToDark,
      onPressed: ref.read(settingsProvider.notifier).toggleTheme,
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
