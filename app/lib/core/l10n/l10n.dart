import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  /// Localised strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
