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
  String get comingNextPhase => 'هذه الصفحة قيد البناء';

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
}
