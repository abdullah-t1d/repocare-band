import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en')
  ];

  /// Product name, not translated.
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

  /// No description provided for @languageTooltip.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get languageTooltip;

  /// No description provided for @themeToDark.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الوضع الداكن'**
  String get themeToDark;

  /// No description provided for @themeToLight.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الوضع الفاتح'**
  String get themeToLight;

  /// No description provided for @dismiss.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get dismiss;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @statusConnected.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get statusConnected;

  /// No description provided for @statusDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get statusDisconnected;

  /// No description provided for @statusConnecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال'**
  String get statusConnecting;

  /// No description provided for @devicesTitle.
  ///
  /// In ar, this message translates to:
  /// **'وصّل السوار'**
  String get devicesTitle;

  /// No description provided for @devicesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر طريقة الاتصال ثم اضغط «اتصال».'**
  String get devicesSubtitle;

  /// Device name, not translated.
  ///
  /// In ar, this message translates to:
  /// **'RepoCare Band'**
  String get deviceName;

  /// Hardware names, not translated.
  ///
  /// In ar, this message translates to:
  /// **'Seeed XIAO nRF52840 Sense · MAX30102'**
  String get deviceHardware;

  /// No description provided for @connectionType.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الاتصال'**
  String get connectionType;

  /// No description provided for @transportUsb.
  ///
  /// In ar, this message translates to:
  /// **'USB'**
  String get transportUsb;

  /// No description provided for @transportDemo.
  ///
  /// In ar, this message translates to:
  /// **'تجريبي'**
  String get transportDemo;

  /// No description provided for @transportBle.
  ///
  /// In ar, this message translates to:
  /// **'Bluetooth'**
  String get transportBle;

  /// No description provided for @comingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get comingSoon;

  /// No description provided for @connect.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In ar, this message translates to:
  /// **'قطع الاتصال'**
  String get disconnect;

  /// No description provided for @reconnect.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الاتصال'**
  String get reconnect;

  /// No description provided for @openLive.
  ///
  /// In ar, this message translates to:
  /// **'عرض القراءات المباشرة'**
  String get openLive;

  /// No description provided for @browserNote.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال عبر USB يحتاج Chrome أو Edge على الكمبيوتر. الوضع التجريبي يشتغل في أي متصفح.'**
  String get browserNote;

  /// No description provided for @unsupportedBrowser.
  ///
  /// In ar, this message translates to:
  /// **'افتح الموقع في Chrome أو Edge على الكمبيوتر'**
  String get unsupportedBrowser;

  /// No description provided for @usbStep1.
  ///
  /// In ar, this message translates to:
  /// **'ارفع برنامج repocare_finger أو repocare_wrist على اللوحة.'**
  String get usbStep1;

  /// No description provided for @usbStep2.
  ///
  /// In ar, this message translates to:
  /// **'سكّر Serial Monitor في Arduino IDE.'**
  String get usbStep2;

  /// No description provided for @usbStep3.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «اتصال» واختر منفذ السوار.'**
  String get usbStep3;

  /// No description provided for @bleNote.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال اللاسلكي يحتاج برنامج Bluetooth للسوار، وهو قيد التطوير.'**
  String get bleNote;

  /// No description provided for @demoPickRecording.
  ///
  /// In ar, this message translates to:
  /// **'اختر تسجيلًا حقيقيًا لتشغيله'**
  String get demoPickRecording;

  /// No description provided for @recFingerRest.
  ///
  /// In ar, this message translates to:
  /// **'الإصبع وقت الراحة'**
  String get recFingerRest;

  /// No description provided for @recFingerRestDetail.
  ///
  /// In ar, this message translates to:
  /// **'80 ثانية · نبض 65–72 بجودة عالية'**
  String get recFingerRestDetail;

  /// No description provided for @recWristBack.
  ///
  /// In ar, this message translates to:
  /// **'ظهر المعصم وقت الراحة'**
  String get recWristBack;

  /// No description provided for @recWristBackDetail.
  ///
  /// In ar, this message translates to:
  /// **'221 ثانية · نبض 61–71، القراءة متاحة قرابة 60% من الوقت'**
  String get recWristBackDetail;

  /// No description provided for @recWristInner.
  ///
  /// In ar, this message translates to:
  /// **'باطن المعصم (بدون نبض)'**
  String get recWristInner;

  /// No description provided for @recWristInnerDetail.
  ///
  /// In ar, this message translates to:
  /// **'134 ثانية · مثال سلبي: السوار لا يعرض رقمًا، وهذا صحيح'**
  String get recWristInnerDetail;

  /// No description provided for @errorPortBusy.
  ///
  /// In ar, this message translates to:
  /// **'المنفذ مستخدم. سكّر Serial Monitor أو أي صفحة ثانية متصلة بالسوار.'**
  String get errorPortBusy;

  /// No description provided for @errorConnectionLost.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال بالسوار (فصل الكيبل أو إعادة تشغيل اللوحة بعد رفع البرنامج). وصّله واضغط «إعادة الاتصال».'**
  String get errorConnectionLost;

  /// No description provided for @errorOpenFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح المنفذ. افصل السوار ووصّله مرة ثانية ثم حاول.'**
  String get errorOpenFailed;

  /// No description provided for @errorRecordingUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل التسجيل التجريبي.'**
  String get errorRecordingUnavailable;

  /// No description provided for @errorNotImplemented.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال عبر Bluetooth غير متاح بعد.'**
  String get errorNotImplemented;

  /// No description provided for @errorSensorMissing.
  ///
  /// In ar, this message translates to:
  /// **'الحساس غير موجود. تأكد من التوصيل: الأزرق على D4 والأصفر على D5، الأحمر على 3V3 والأسود على GND.'**
  String get errorSensorMissing;

  /// No description provided for @notConnectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'السوار غير متصل'**
  String get notConnectedTitle;

  /// No description provided for @notConnectedBody.
  ///
  /// In ar, this message translates to:
  /// **'وصّل السوار عبر USB أو شغّل تسجيلًا تجريبيًا من صفحة الأجهزة.'**
  String get notConnectedBody;

  /// No description provided for @goToDevices.
  ///
  /// In ar, this message translates to:
  /// **'الذهاب إلى الأجهزة'**
  String get goToDevices;

  /// No description provided for @demoPlayback.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل تجريبي'**
  String get demoPlayback;

  /// No description provided for @demoPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get demoPause;

  /// No description provided for @demoResume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get demoResume;

  /// No description provided for @demoRestart.
  ///
  /// In ar, this message translates to:
  /// **'من البداية'**
  String get demoRestart;

  /// No description provided for @demoSpeed.
  ///
  /// In ar, this message translates to:
  /// **'السرعة'**
  String get demoSpeed;

  /// No description provided for @heartRate.
  ///
  /// In ar, this message translates to:
  /// **'معدل النبض'**
  String get heartRate;

  /// No description provided for @unitBpm.
  ///
  /// In ar, this message translates to:
  /// **'نبضة/دقيقة'**
  String get unitBpm;

  /// No description provided for @unitBpmLong.
  ///
  /// In ar, this message translates to:
  /// **'نبضة في الدقيقة'**
  String get unitBpmLong;

  /// Under a held heart rate: the firmware repeats its last good value while the signal is weak.
  ///
  /// In ar, this message translates to:
  /// **'آخر قراءة'**
  String get lastReading;

  /// Milliseconds, kept as ms in both languages.
  ///
  /// In ar, this message translates to:
  /// **'ms'**
  String get unitMs;

  /// No description provided for @zoneLow.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get zoneLow;

  /// No description provided for @zoneNormal.
  ///
  /// In ar, this message translates to:
  /// **'طبيعي'**
  String get zoneNormal;

  /// No description provided for @zoneElevated.
  ///
  /// In ar, this message translates to:
  /// **'مرتفع'**
  String get zoneElevated;

  /// No description provided for @zoneHigh.
  ///
  /// In ar, this message translates to:
  /// **'مرتفع جدًا'**
  String get zoneHigh;

  /// No description provided for @zoneLowCaption.
  ///
  /// In ar, this message translates to:
  /// **'أقل من المعتاد وقت الراحة'**
  String get zoneLowCaption;

  /// No description provided for @zoneNormalCaption.
  ///
  /// In ar, this message translates to:
  /// **'ضمن المعتاد وقت الراحة'**
  String get zoneNormalCaption;

  /// No description provided for @zoneElevatedCaption.
  ///
  /// In ar, this message translates to:
  /// **'أعلى من المعتاد وقت الراحة'**
  String get zoneElevatedCaption;

  /// No description provided for @zoneHighCaption.
  ///
  /// In ar, this message translates to:
  /// **'أعلى بكثير من المعتاد وقت الراحة، خذ قسطًا من الراحة وأعد القياس'**
  String get zoneHighCaption;

  /// No description provided for @pulseWave.
  ///
  /// In ar, this message translates to:
  /// **'موجة النبض'**
  String get pulseWave;

  /// No description provided for @lastSixSeconds.
  ///
  /// In ar, this message translates to:
  /// **'آخر 6 ثوانٍ'**
  String get lastSixSeconds;

  /// No description provided for @waveEmpty.
  ///
  /// In ar, this message translates to:
  /// **'موجة النبض تظهر هنا بعد الاتصال'**
  String get waveEmpty;

  /// No description provided for @spo2Title.
  ///
  /// In ar, this message translates to:
  /// **'الأكسجين في الدم'**
  String get spo2Title;

  /// No description provided for @estimateBadge.
  ///
  /// In ar, this message translates to:
  /// **'تقديري'**
  String get estimateBadge;

  /// No description provided for @spo2Note.
  ///
  /// In ar, this message translates to:
  /// **'من الإصبع فقط، غير معاير'**
  String get spo2Note;

  /// No description provided for @spo2WristNote.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح على المعصم'**
  String get spo2WristNote;

  /// No description provided for @hrvTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقلب النبض (HRV)'**
  String get hrvTitle;

  /// No description provided for @hrvNote.
  ///
  /// In ar, this message translates to:
  /// **'RMSSD لآخر 60 ثانية، يتحدّث كل 10 ثوانٍ'**
  String get hrvNote;

  /// No description provided for @hrvNeedsStillness.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج دقيقة ثبات'**
  String get hrvNeedsStillness;

  /// No description provided for @hrvSteadyProgress.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} من {target} ث'**
  String hrvSteadyProgress(int seconds, int target);

  /// No description provided for @qualityTitle.
  ///
  /// In ar, this message translates to:
  /// **'جودة الإشارة'**
  String get qualityTitle;

  /// No description provided for @chipTempTitle.
  ///
  /// In ar, this message translates to:
  /// **'حرارة شريحة الحساس'**
  String get chipTempTitle;

  /// No description provided for @chipTempNote.
  ///
  /// In ar, this message translates to:
  /// **'حرارة شريحة الحساس، مو حرارة الجسم'**
  String get chipTempNote;

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

  /// No description provided for @trendTitle.
  ///
  /// In ar, this message translates to:
  /// **'النبض خلال آخر دقيقتين'**
  String get trendTitle;

  /// No description provided for @trendEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قراءات بعد'**
  String get trendEmpty;

  /// No description provided for @controlsTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحكم'**
  String get controlsTitle;

  /// No description provided for @ledBrightness.
  ///
  /// In ar, this message translates to:
  /// **'شدة الإضاءة'**
  String get ledBrightness;

  /// No description provided for @ledAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get ledAuto;

  /// No description provided for @resetAnalysis.
  ///
  /// In ar, this message translates to:
  /// **'إعادة القياس'**
  String get resetAnalysis;

  /// No description provided for @startRecording.
  ///
  /// In ar, this message translates to:
  /// **'بدء التسجيل'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف التسجيل'**
  String get stopRecording;

  /// No description provided for @exportCsv.
  ///
  /// In ar, this message translates to:
  /// **'حفظ CSV'**
  String get exportCsv;

  /// No description provided for @recordedRows.
  ///
  /// In ar, this message translates to:
  /// **'{rows} صف مسجّل'**
  String recordedRows(String rows);

  /// No description provided for @demoCommandsNote.
  ///
  /// In ar, this message translates to:
  /// **'الأوامر لا تؤثر على التسجيل التجريبي.'**
  String get demoCommandsNote;

  /// No description provided for @rawTitle.
  ///
  /// In ar, this message translates to:
  /// **'البيانات الخام'**
  String get rawTitle;

  /// No description provided for @perfusionIndex.
  ///
  /// In ar, this message translates to:
  /// **'قوة النبض (PI)'**
  String get perfusionIndex;

  /// No description provided for @ledCurrent.
  ///
  /// In ar, this message translates to:
  /// **'تيار الإضاءة'**
  String get ledCurrent;

  /// No description provided for @storedBeats.
  ///
  /// In ar, this message translates to:
  /// **'نبضات محسوبة'**
  String get storedBeats;

  /// No description provided for @signalChannel.
  ///
  /// In ar, this message translates to:
  /// **'الإشارة المستخدمة'**
  String get signalChannel;

  /// No description provided for @deviceMessages.
  ///
  /// In ar, this message translates to:
  /// **'آخر رسائل الجهاز'**
  String get deviceMessages;

  /// No description provided for @noMessages.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل'**
  String get noMessages;

  /// No description provided for @measureTitle.
  ///
  /// In ar, this message translates to:
  /// **'قياس موجّه'**
  String get measureTitle;

  /// No description provided for @measureIntro.
  ///
  /// In ar, this message translates to:
  /// **'اختر طريقة القياس. قياس الإصبع يستمر حتى يُحسب HRV (75 ثانية كحد أقصى)، وقياس المعصم ينتهي مبكرًا لما تستقر القراءة.'**
  String get measureIntro;

  /// No description provided for @measureNeedsConnection.
  ///
  /// In ar, this message translates to:
  /// **'وصّل السوار أولًا لبدء القياس.'**
  String get measureNeedsConnection;

  /// No description provided for @siteFinger.
  ///
  /// In ar, this message translates to:
  /// **'قياس الإصبع'**
  String get siteFinger;

  /// No description provided for @siteFingerDetail.
  ///
  /// In ar, this message translates to:
  /// **'حتى 75 ثانية · النبض والأكسجين التقديري و HRV'**
  String get siteFingerDetail;

  /// No description provided for @siteWrist.
  ///
  /// In ar, this message translates to:
  /// **'قياس المعصم'**
  String get siteWrist;

  /// No description provided for @siteWristDetail.
  ///
  /// In ar, this message translates to:
  /// **'60 ثانية · النبض من ظهر المعصم'**
  String get siteWristDetail;

  /// No description provided for @instructionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل ما نبدأ'**
  String get instructionsTitle;

  /// No description provided for @instructionsFinger.
  ///
  /// In ar, this message translates to:
  /// **'حط يدك على الطاولة، وريّح إصبعك على الحساس بدون ضغط، ولا تتحرك. النبض يظهر خلال ثوانٍ، و HRV يحتاج دقيقة ثبات كاملة (حتى 75 ثانية).'**
  String get instructionsFinger;

  /// No description provided for @instructionsWrist.
  ///
  /// In ar, this message translates to:
  /// **'تأكد إن السوار مشدود فوق عظمة المعصم بإصبع، وخلّ يدك ثابتة على سطح لمدة دقيقة.'**
  String get instructionsWrist;

  /// No description provided for @startMeasurement.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ القياس'**
  String get startMeasurement;

  /// No description provided for @waitingFinger.
  ///
  /// In ar, this message translates to:
  /// **'ضع إصبعك على الحساس…'**
  String get waitingFinger;

  /// No description provided for @waitingWrist.
  ///
  /// In ar, this message translates to:
  /// **'ننتظر ملامسة الحساس للمعصم…'**
  String get waitingWrist;

  /// No description provided for @measuringHoldStill.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت يدك… جاري القياس'**
  String get measuringHoldStill;

  /// No description provided for @secondsLeft.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث متبقية'**
  String secondsLeft(String seconds);

  /// No description provided for @secondsValue.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث'**
  String secondsValue(String seconds);

  /// No description provided for @stability.
  ///
  /// In ar, this message translates to:
  /// **'ثبات القراءة'**
  String get stability;

  /// No description provided for @liveQuality.
  ///
  /// In ar, this message translates to:
  /// **'جودة الإشارة الآن'**
  String get liveQuality;

  /// No description provided for @measureProgress.
  ///
  /// In ar, this message translates to:
  /// **'تقدم القياس'**
  String get measureProgress;

  /// No description provided for @firmwareMismatchFinger.
  ///
  /// In ar, this message translates to:
  /// **'السوار يشغّل برنامج المعصم. لقياس الإصبع ارفع برنامج repocare_finger.'**
  String get firmwareMismatchFinger;

  /// No description provided for @firmwareMismatchWrist.
  ///
  /// In ar, this message translates to:
  /// **'السوار يشغّل برنامج الإصبع. لقياس المعصم ارفع برنامج repocare_wrist.'**
  String get firmwareMismatchWrist;

  /// No description provided for @resultTitle.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get resultTitle;

  /// No description provided for @resultFailed.
  ///
  /// In ar, this message translates to:
  /// **'ما قدرنا نقيس بدقة، ثبّت يدك وحاول مرة ثانية'**
  String get resultFailed;

  /// No description provided for @resultEndedEarly.
  ///
  /// In ar, this message translates to:
  /// **'انتهى مبكرًا لأن القراءة مستقرة'**
  String get resultEndedEarly;

  /// No description provided for @resultEndedWithHrv.
  ///
  /// In ar, this message translates to:
  /// **'انتهى بعد حساب HRV'**
  String get resultEndedWithHrv;

  /// No description provided for @resultEndedTimeout.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت القياس'**
  String get resultEndedTimeout;

  /// No description provided for @resultHrvUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'HRV غير متاح: يحتاج دقيقة ثبات كاملة'**
  String get resultHrvUnavailable;

  /// Abbreviation, kept in Latin letters.
  ///
  /// In ar, this message translates to:
  /// **'HRV'**
  String get resultHrv;

  /// No description provided for @resultSpo2.
  ///
  /// In ar, this message translates to:
  /// **'الأكسجين (تقديري)'**
  String get resultSpo2;

  /// No description provided for @resultQuality.
  ///
  /// In ar, this message translates to:
  /// **'الجودة'**
  String get resultQuality;

  /// No description provided for @resultDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get resultDuration;

  /// No description provided for @resultTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get resultTime;

  /// No description provided for @measureAgain.
  ///
  /// In ar, this message translates to:
  /// **'قياس جديد'**
  String get measureAgain;

  /// No description provided for @measureDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال أثناء القياس، فتوقف بدون نتيجة.'**
  String get measureDisconnected;

  /// No description provided for @historyTitle.
  ///
  /// In ar, this message translates to:
  /// **'قياسات هذه الجلسة'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قياسات بعد'**
  String get historyEmpty;

  /// No description provided for @historyNote.
  ///
  /// In ar, this message translates to:
  /// **'محفوظة في هذه الجلسة فقط'**
  String get historyNote;

  /// No description provided for @historyNoReading.
  ///
  /// In ar, this message translates to:
  /// **'بدون قراءة موثوقة'**
  String get historyNoReading;

  /// No description provided for @comingNextPhase.
  ///
  /// In ar, this message translates to:
  /// **'هذه الصفحة قيد البناء'**
  String get comingNextPhase;

  /// No description provided for @clearHistory.
  ///
  /// In ar, this message translates to:
  /// **'مسح السجل'**
  String get clearHistory;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
