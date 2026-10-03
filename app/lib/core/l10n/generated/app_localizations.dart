import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'repoCare Band'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قراءات حساس النبض MAX30102'**
  String get appSubtitle;

  /// No description provided for @navDevices.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة'**
  String get navDevices;

  /// No description provided for @navLive.
  ///
  /// In ar, this message translates to:
  /// **'القراءات المباشرة'**
  String get navLive;

  /// No description provided for @navMeasure.
  ///
  /// In ar, this message translates to:
  /// **'قياس موجّه'**
  String get navMeasure;

  /// No description provided for @footerDisclaimer.
  ///
  /// In ar, this message translates to:
  /// **'نموذج أولي لمشروع تخرج، غير تشخيصي'**
  String get footerDisclaimer;

  /// No description provided for @comingNextPhase.
  ///
  /// In ar, this message translates to:
  /// **'هذه الصفحة قيد البناء'**
  String get comingNextPhase;

  /// No description provided for @qualityExcellent.
  ///
  /// In ar, this message translates to:
  /// **'ممتازة'**
  String get qualityExcellent;

  /// No description provided for @qualityAcceptable.
  ///
  /// In ar, this message translates to:
  /// **'مقبولة'**
  String get qualityAcceptable;

  /// No description provided for @qualityWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيفة'**
  String get qualityWeak;

  /// No description provided for @qualityNone.
  ///
  /// In ar, this message translates to:
  /// **'--'**
  String get qualityNone;

  /// No description provided for @hintSaturated.
  ///
  /// In ar, this message translates to:
  /// **'الإضاءة قوية والإشارة مشبعة. اختر مستوى إضاءة أقل.'**
  String get hintSaturated;

  /// No description provided for @hintNoContact.
  ///
  /// In ar, this message translates to:
  /// **'ضع إصبعك على الحساس بضغط خفيف وثابت.'**
  String get hintNoContact;

  /// No description provided for @hintMotion.
  ///
  /// In ar, this message translates to:
  /// **'تحركت يدك. القراءة متوقفة لين تثبت.'**
  String get hintMotion;

  /// No description provided for @hintSettling.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت يدك على الطاولة ولا تتحرك… جاري حساب النبض.'**
  String get hintSettling;

  /// No description provided for @hintWeakSignal.
  ///
  /// In ar, this message translates to:
  /// **'الإشارة ضعيفة. خفف الضغط وثبّت يدك على الطاولة.'**
  String get hintWeakSignal;

  /// No description provided for @hintStable.
  ///
  /// In ar, this message translates to:
  /// **'القراءة مستقرة.'**
  String get hintStable;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
