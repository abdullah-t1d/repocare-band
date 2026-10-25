import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:repocare_band/core/router/app_routes.dart';
import 'package:repocare_band/core/settings/app_settings.dart';
import 'package:repocare_band/core/widgets/header_actions.dart';
import 'package:repocare_band/features/band/domain/measurement/session_result.dart';
import 'package:repocare_band/features/band/presentation/pages/devices_page.dart';
import 'package:repocare_band/features/band/presentation/pages/live_page.dart';
import 'package:repocare_band/features/band/presentation/pages/measure_page.dart';
import 'package:repocare_band/features/band/presentation/providers/band_providers.dart';
import 'package:repocare_band/features/band/presentation/providers/measure_controller.dart';

import '../support/test_app.dart';

/// Connects the demo with [recording] (by name) and opens the measure page.
Future<void> _openMeasure(WidgetTester tester, {String? recording}) async {
  Future<void> tapVisible(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(); // the scroll is laid out on the next frame
    await tester.tap(f);
  }

  if (recording != null) {
    await tapVisible(find.byKey(ValueKey('recording-$recording')));
    await tester.pump();
  }
  await tapVisible(find.byKey(DevicesPage.connectKey));
  await tester.pump();
  await tester.pump();
  GoRouter.of(tester.element(find.byType(LivePage))).go(AppRoutes.measure);
  await tester.pump();
  expect(find.byType(MeasurePage), findsOneWidget);
}

Future<void> _start(WidgetTester tester, Key mode) async {
  await tester.tap(find.byKey(mode));
  await tester.pump();
  await tester.tap(find.byKey(MeasurePage.startKey));
  await tester.pump();
}

String _text(WidgetTester tester, Key key) => tester.widget<Text>(find.byKey(key)).data!;

void main() {
  late PreloadedDemoFactory demo;

  setUpAll(() async => demo = await PreloadedDemoFactory.load());

  testWidgets('finger recording: live ring, then a result after 75 s without HRV', (tester) async {
    final c = await pumpApp(tester, transports: demo);
    await _openMeasure(tester);

    expect(find.text('قياس الإصبع'), findsOneWidget);
    expect(find.text('قياس المعصم'), findsOneWidget);
    await tester.tap(find.byKey(MeasurePage.fingerKey));
    await tester.pump();
    expect(find.text('قبل ما نبدأ'), findsOneWidget, reason: 'instructions before starting');
    await tester.tap(find.byKey(MeasurePage.startKey));
    await tester.pump();

    await pumpFor(tester, const Duration(seconds: 15), step: const Duration(milliseconds: 250));
    expect(find.byKey(MeasurePage.ringKey), findsOneWidget);
    expect(int.parse(_text(tester, MeasurePage.liveBpmKey)), inInclusiveRange(55, 85),
        reason: 'heart rate shows early');
    expect(find.text('يحتاج دقيقة ثبات'), findsOneWidget, reason: 'the recording has no RMSSD');
    expect(find.textContaining('من 60 ث'), findsOneWidget);
    expect(c.read(measureControllerProvider).step, MeasureStep.measuring, reason: 'no early stop on the finger');

    await pumpFor(tester, const Duration(seconds: 62), step: const Duration(milliseconds: 250));
    final state = c.read(measureControllerProvider);
    expect(state.step, MeasureStep.result);
    final result = state.result!;
    expect(result.endReason, SessionEndReason.timeout);
    expect(result.isSuccess, isTrue);

    expect(find.byKey(MeasurePage.resultKey), findsOneWidget);
    expect(int.parse(_text(tester, MeasurePage.resultBpmKey)), inInclusiveRange(60, 80));
    expect(find.text('طبيعي'), findsWidgets, reason: 'zone label');
    expect(find.text('ضمن المعتاد وقت الراحة'), findsOneWidget, reason: 'calm wording');
    expect(find.text('الأكسجين (تقديري)'), findsWidgets);
    expect(find.text('HRV غير متاح: يحتاج دقيقة ثبات كاملة'), findsOneWidget);
    expect(find.text('انتهى وقت القياس'), findsOneWidget, reason: 'why it ended');
    expect(find.byKey(MeasurePage.failureKey), findsNothing);
    expect(state.history, hasLength(1));
    expect(find.text('لا توجد قياسات بعد'), findsNothing);

    await tearDownApp(tester, c);
  });

  testWidgets('inner-wrist recording: fails cleanly after 60 s', (tester) async {
    final c = await pumpApp(tester, transports: demo);
    await _openMeasure(tester, recording: 'wristInnerNoPulse');
    await _start(tester, MeasurePage.wristKey);

    await pumpFor(tester, const Duration(seconds: 30), step: const Duration(milliseconds: 250));
    expect(_text(tester, MeasurePage.liveBpmKey), '--', reason: 'never a made-up number');
    expect(find.text('ثبات القراءة'), findsOneWidget, reason: 'wrist shows stability, not HRV');

    await pumpFor(tester, const Duration(seconds: 31), step: const Duration(milliseconds: 250));
    final state = c.read(measureControllerProvider);
    expect(state.step, MeasureStep.result);
    expect(state.result!.isSuccess, isFalse);
    expect(find.byKey(MeasurePage.failureKey), findsOneWidget);
    expect(find.text('ما قدرنا نقيس بدقة، ثبّت يدك وحاول مرة ثانية'), findsOneWidget);
    expect(find.text('الأكسجين (تقديري)'), findsNothing, reason: 'no SpO2 on the wrist');
    expect(find.text('بدون قراءة موثوقة'), findsOneWidget, reason: 'history row');
    expect(tester.takeException(), isNull);

    // Measure again goes back to the same mode's instructions.
    await tester.tap(find.byKey(MeasurePage.againKey));
    await tester.pump();
    expect(c.read(measureControllerProvider).step, MeasureStep.instructions);
    expect(find.byKey(MeasurePage.startKey), findsOneWidget);

    await tearDownApp(tester, c);
  });

  testWidgets('English, dark theme and reduce motion: the measuring view still works', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await pumpApp(tester, transports: demo, prefs: {SettingsController.localeKey: 'en'});
    await tester.tap(find.byKey(ThemeToggle.buttonKey));
    await tester.pump();
    await _openMeasure(tester);

    expect(find.text('Finger measurement'), findsOneWidget);
    await _start(tester, MeasurePage.fingerKey);
    await pumpFor(tester, const Duration(seconds: 12), step: const Duration(milliseconds: 250));
    expect(Directionality.of(tester.element(find.byKey(MeasurePage.ringKey))), TextDirection.ltr);
    expect(find.text('Needs 1 minute of stillness'), findsOneWidget);
    expect(find.text('Signal quality now'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(MeasurePage))).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(MeasurePage.cancelKey));
    await tester.pump();
    expect(c.read(measureControllerProvider).step, MeasureStep.instructions);
    expect(c.read(measureControllerProvider).history, isEmpty, reason: 'cancelled runs are not kept');

    await tearDownApp(tester, c);
  });

  testWidgets('phone width: measuring and failure screens fit without overflow', (tester) async {
    final c = await pumpApp(tester, transports: demo, size: const Size(390, 844));
    await _openMeasure(tester, recording: 'wristInnerNoPulse');
    await _start(tester, MeasurePage.wristKey);
    await pumpFor(tester, const Duration(seconds: 5), step: const Duration(milliseconds: 250));
    expect(find.byKey(MeasurePage.ringKey), findsOneWidget);
    expect(tester.getSize(find.byKey(MeasurePage.ringKey)).width, lessThanOrEqualTo(390));
    await pumpFor(tester, const Duration(seconds: 57), step: const Duration(milliseconds: 500));
    expect(find.byKey(MeasurePage.failureKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, c);
  });

  testWidgets('disconnecting during a measurement stops it with a message', (tester) async {
    final c = await pumpApp(tester, transports: demo);
    await _openMeasure(tester);
    await _start(tester, MeasurePage.fingerKey);
    await pumpFor(tester, const Duration(seconds: 3), step: const Duration(milliseconds: 250));

    await c.read(connectionControllerProvider.notifier).disconnect();
    await tester.pump();
    expect(find.text('انقطع الاتصال أثناء القياس، فتوقف بدون نتيجة.'), findsOneWidget);
    expect(c.read(measureControllerProvider).history, isEmpty);

    await tearDownApp(tester, c);
  });
}
