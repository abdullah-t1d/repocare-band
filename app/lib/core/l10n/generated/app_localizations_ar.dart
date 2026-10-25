import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'repoCare Band';

  @override
  String get appSubtitle => 'قراءات حساس النبض MAX30102';

  @override
  String get navDevices => 'الأجهزة';

  @override
  String get navLive => 'القراءات المباشرة';

  @override
  String get navMeasure => 'قياس موجّه';

  @override
  String get footerDisclaimer => 'نموذج أولي لمشروع تخرج، غير تشخيصي';

  @override
  String get languageTooltip => 'اللغة';

  @override
  String get themeToDark => 'تفعيل الوضع الداكن';

  @override
  String get themeToLight => 'تفعيل الوضع الفاتح';

  @override
  String get dismiss => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get cancel => 'إلغاء';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusDisconnected => 'غير متصل';

  @override
  String get statusConnecting => 'جاري الاتصال';

  @override
  String get devicesTitle => 'وصّل السوار';

  @override
  String get devicesSubtitle => 'اختر طريقة الاتصال ثم اضغط «اتصال».';

  @override
  String get deviceName => 'RepoCare Band';

  @override
  String get deviceHardware => 'Seeed XIAO nRF52840 Sense · MAX30102';

  @override
  String get connectionType => 'طريقة الاتصال';

  @override
  String get transportUsb => 'USB';

  @override
  String get transportDemo => 'تجريبي';

  @override
  String get transportBle => 'Bluetooth';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع الاتصال';

  @override
  String get reconnect => 'إعادة الاتصال';

  @override
  String get openLive => 'عرض القراءات المباشرة';

  @override
  String get browserNote => 'الاتصال عبر USB يحتاج Chrome أو Edge على الكمبيوتر. الوضع التجريبي يشتغل في أي متصفح.';

  @override
  String get unsupportedBrowser => 'افتح الموقع في Chrome أو Edge على الكمبيوتر';

  @override
  String get usbStep1 => 'ارفع برنامج repocare_finger أو repocare_wrist على اللوحة.';

  @override
  String get usbStep2 => 'سكّر Serial Monitor في Arduino IDE.';

  @override
  String get usbStep3 => 'اضغط «اتصال» واختر منفذ السوار.';

  @override
  String get bleNote => 'الاتصال اللاسلكي يحتاج برنامج Bluetooth للسوار، وهو قيد التطوير.';

  @override
  String get demoPickRecording => 'اختر تسجيلًا حقيقيًا لتشغيله';

  @override
  String get recFingerRest => 'الإصبع وقت الراحة';

  @override
  String get recFingerRestDetail => '80 ثانية · نبض 65–72 بجودة عالية';

  @override
  String get recWristBack => 'ظهر المعصم وقت الراحة';

  @override
  String get recWristBackDetail => '221 ثانية · نبض 61–71، القراءة متاحة قرابة 60% من الوقت';

  @override
  String get recWristInner => 'باطن المعصم (بدون نبض)';

  @override
  String get recWristInnerDetail => '134 ثانية · مثال سلبي: السوار لا يعرض رقمًا، وهذا صحيح';

  @override
  String get errorPortBusy => 'المنفذ مستخدم. سكّر Serial Monitor أو أي صفحة ثانية متصلة بالسوار.';

  @override
  String get errorConnectionLost => 'انقطع الاتصال بالسوار (فصل الكيبل أو إعادة تشغيل اللوحة بعد رفع البرنامج). وصّله واضغط «إعادة الاتصال».';

  @override
  String get errorOpenFailed => 'تعذّر فتح المنفذ. افصل السوار ووصّله مرة ثانية ثم حاول.';

  @override
  String get errorRecordingUnavailable => 'تعذّر تحميل التسجيل التجريبي.';

  @override
  String get errorNotImplemented => 'الاتصال عبر Bluetooth غير متاح بعد.';

  @override
  String get errorSensorMissing => 'الحساس غير موجود. تأكد من التوصيل: الأزرق على D4 والأصفر على D5، الأحمر على 3V3 والأسود على GND.';

  @override
  String get notConnectedTitle => 'السوار غير متصل';

  @override
  String get notConnectedBody => 'وصّل السوار عبر USB أو شغّل تسجيلًا تجريبيًا من صفحة الأجهزة.';

  @override
  String get goToDevices => 'الذهاب إلى الأجهزة';

  @override
  String get demoPlayback => 'تشغيل تجريبي';

  @override
  String get demoPause => 'إيقاف مؤقت';

  @override
  String get demoResume => 'استئناف';

  @override
  String get demoRestart => 'من البداية';

  @override
  String get demoSpeed => 'السرعة';

  @override
  String get heartRate => 'معدل النبض';

  @override
  String get unitBpm => 'نبضة/دقيقة';

  @override
  String get unitBpmLong => 'نبضة في الدقيقة';

  @override
  String get unitMs => 'ms';

  @override
  String get zoneLow => 'منخفض';

  @override
  String get zoneNormal => 'طبيعي';

  @override
  String get zoneElevated => 'مرتفع';

  @override
  String get zoneHigh => 'مرتفع جدًا';

  @override
  String get zoneLowCaption => 'أقل من المعتاد وقت الراحة';

  @override
  String get zoneNormalCaption => 'ضمن المعتاد وقت الراحة';

  @override
  String get zoneElevatedCaption => 'أعلى من المعتاد وقت الراحة';

  @override
  String get zoneHighCaption => 'أعلى بكثير من المعتاد وقت الراحة، خذ قسطًا من الراحة وأعد القياس';

  @override
  String get pulseWave => 'موجة النبض';

  @override
  String get lastSixSeconds => 'آخر 6 ثوانٍ';

  @override
  String get waveEmpty => 'موجة النبض تظهر هنا بعد الاتصال';

  @override
  String get spo2Title => 'الأكسجين في الدم';

  @override
  String get estimateBadge => 'تقديري';

  @override
  String get spo2Note => 'من الإصبع فقط، غير معاير';

  @override
  String get spo2WristNote => 'غير متاح على المعصم';

  @override
  String get hrvTitle => 'تقلب النبض (HRV)';

  @override
  String get hrvNote => 'RMSSD من النبضات النظيفة';

  @override
  String get qualityTitle => 'جودة الإشارة';

  @override
  String get chipTempTitle => 'حرارة شريحة الحساس';

  @override
  String get chipTempNote => 'حرارة شريحة الحساس، مو حرارة الجسم';

  @override
  String get qualityExcellent => 'ممتازة';

  @override
  String get qualityAcceptable => 'مقبولة';

  @override
  String get qualityWeak => 'ضعيفة';

  @override
  String get qualityNone => '--';

  @override
  String get hintSaturated => 'الإضاءة قوية والإشارة مشبعة. اختر مستوى إضاءة أقل.';

  @override
  String get hintNoContact => 'ضع إصبعك على الحساس بضغط خفيف وثابت.';

  @override
  String get hintMotion => 'تحركت يدك. القراءة متوقفة لين تثبت.';

  @override
  String get hintSettling => 'ثبّت يدك على الطاولة ولا تتحرك… جاري حساب النبض.';

  @override
  String get hintWeakSignal => 'الإشارة ضعيفة. خفف الضغط وثبّت يدك على الطاولة.';

  @override
  String get hintStable => 'القراءة مستقرة.';

  @override
  String get trendTitle => 'النبض خلال آخر دقيقتين';

  @override
  String get trendEmpty => 'لا توجد قراءات بعد';

  @override
  String get controlsTitle => 'التحكم';

  @override
  String get ledBrightness => 'شدة الإضاءة';

  @override
  String get ledAuto => 'تلقائي';

  @override
  String get resetAnalysis => 'إعادة القياس';

  @override
  String get startRecording => 'بدء التسجيل';

  @override
  String get stopRecording => 'إيقاف التسجيل';

  @override
  String get exportCsv => 'حفظ CSV';

  @override
  String recordedRows(String rows) {
    return '$rows صف مسجّل';
  }

  @override
  String get demoCommandsNote => 'الأوامر لا تؤثر على التسجيل التجريبي.';

  @override
  String get rawTitle => 'البيانات الخام';

  @override
  String get perfusionIndex => 'قوة النبض (PI)';

  @override
  String get ledCurrent => 'تيار الإضاءة';

  @override
  String get storedBeats => 'نبضات محسوبة';

  @override
  String get signalChannel => 'الإشارة المستخدمة';

  @override
  String get deviceMessages => 'آخر رسائل الجهاز';

  @override
  String get noMessages => 'لا توجد رسائل';

  @override
  String get measureTitle => 'قياس موجّه';

  @override
  String get measureIntro => 'اختر طريقة القياس. التطبيق يوقف القياس مبكرًا لما تكون القراءة مستقرة.';

  @override
  String get measureNeedsConnection => 'وصّل السوار أولًا لبدء القياس.';

  @override
  String get siteFinger => 'قياس الإصبع';

  @override
  String get siteFingerDetail => '30 ثانية · النبض و HRV والأكسجين التقديري';

  @override
  String get siteWrist => 'قياس المعصم';

  @override
  String get siteWristDetail => '60 ثانية · النبض من ظهر المعصم';

  @override
  String get instructionsTitle => 'قبل ما نبدأ';

  @override
  String get instructionsFinger => 'حط يدك على الطاولة، وريّح إصبعك على الحساس بدون ضغط، ولا تتحرك 30 ثانية.';

  @override
  String get instructionsWrist => 'تأكد إن السوار مشدود فوق عظمة المعصم بإصبع، وخلّ يدك ثابتة على سطح لمدة دقيقة.';

  @override
  String get startMeasurement => 'ابدأ القياس';

  @override
  String get waitingFinger => 'ضع إصبعك على الحساس…';

  @override
  String get waitingWrist => 'ننتظر ملامسة الحساس للمعصم…';

  @override
  String get measuringHoldStill => 'ثبّت يدك… جاري القياس';

  @override
  String secondsLeft(String seconds) {
    return '$seconds ث متبقية';
  }

  @override
  String secondsValue(String seconds) {
    return '$seconds ث';
  }

  @override
  String get stability => 'ثبات القراءة';

  @override
  String get liveQuality => 'جودة الإشارة الآن';

  @override
  String get firmwareMismatchFinger => 'السوار يشغّل برنامج المعصم. لقياس الإصبع ارفع برنامج repocare_finger.';

  @override
  String get firmwareMismatchWrist => 'السوار يشغّل برنامج الإصبع. لقياس المعصم ارفع برنامج repocare_wrist.';

  @override
  String get resultTitle => 'النتيجة';

  @override
  String get resultFailed => 'ما قدرنا نقيس بدقة، ثبّت يدك وحاول مرة ثانية';

  @override
  String get resultEndedEarly => 'انتهى مبكرًا لأن القراءة مستقرة';

  @override
  String get resultHrv => 'HRV';

  @override
  String get resultSpo2 => 'الأكسجين (تقديري)';

  @override
  String get resultQuality => 'الجودة';

  @override
  String get resultDuration => 'المدة';

  @override
  String get resultTime => 'الوقت';

  @override
  String get measureAgain => 'قياس جديد';

  @override
  String get measureDisconnected => 'انقطع الاتصال أثناء القياس، فتوقف بدون نتيجة.';

  @override
  String get historyTitle => 'قياسات هذه الجلسة';

  @override
  String get historyEmpty => 'لا توجد قياسات بعد';

  @override
  String get historyNote => 'محفوظة في هذه الجلسة فقط';

  @override
  String get historyNoReading => 'بدون قراءة موثوقة';

  @override
  String get comingNextPhase => 'هذه الصفحة قيد البناء';

  @override
  String get clearHistory => 'مسح السجل';
}
