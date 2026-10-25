import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:repocare_band/core/router/app_routes.dart';
import 'package:repocare_band/features/band/domain/enums.dart';
import 'package:repocare_band/features/band/presentation/pages/devices_page.dart';
import 'package:repocare_band/features/band/presentation/pages/live_page.dart';
import 'package:repocare_band/features/band/presentation/pages/measure_page.dart';
import 'package:repocare_band/features/band/presentation/providers/measure_controller.dart';
import 'package:repocare_band/features/band/presentation/widgets/controls_panel.dart';

import '../support/fake_transport.dart';
import '../support/test_app.dart';

/// `M` line: 72 BPM at quality 85 with contact unless told otherwise.
String _m({double bpm = 72, int contact = 1, int quality = 85}) =>
    'M,$bpm,-1,-1,$contact,$quality,33.10,0,0,8,2.10,0,1,6.2';

Future<FakeTransport> _connect(WidgetTester tester, FakeTransportFactory factory) async {
  await tester.tap(find.byKey(DevicesPage.connectKey));
  await tester.pumpAndSettle();
  return factory.last;
}

Future<void> _send(WidgetTester tester, FakeTransport band, String line) async {
  band.push(line);
  await tester.pump();
  await tester.pump();
}

SegmentedButton<MeasureSite> _switch(WidgetTester tester) =>
    tester.widget<SegmentedButton<MeasureSite>>(find.byKey(ControlsPanel.profileKey));

Future<void> _openMeasure(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(LivePage))).go(AppRoutes.measure);
  await tester.pump();
}

Future<void> _startMeasure(WidgetTester tester, Key mode) async {
  await tester.tap(find.byKey(mode));
  await tester.pump();
  await tester.tap(find.byKey(MeasurePage.startKey));
  await tester.pump();
}

void main() {
  late PreloadedDemoFactory demo;

  // File I/O does not complete inside the fake-async zone of widget tests.
  setUpAll(() async => demo = await PreloadedDemoFactory.load());

  group('live page profile switch', () {
    testWidgets('sends f / w and shows the mode from the last #MODE line', (tester) async {
      final factory = FakeTransportFactory();
      final c = await pumpApp(tester, transports: factory);
      final band = await _connect(tester, factory);
      await tester.ensureVisible(find.byKey(ControlsPanel.profileKey));
      await tester.pump();

      expect(_switch(tester).selected, isEmpty, reason: 'no #MODE yet');
      expect(find.text('لم يُبلغ السوار عن وضعه بعد'), findsOneWidget);

      await _send(tester, band, '#MODE finger');
      expect(_switch(tester).selected, {MeasureSite.finger});

      await tester.tap(find.descendant(of: find.byKey(ControlsPanel.profileKey), matching: find.text('المعصم')));
      await tester.pump();
      expect(band.sent.last, 'w');
      expect(_switch(tester).selected, {MeasureSite.finger}, reason: 'unchanged until the firmware confirms');

      await _send(tester, band, '#MODE wrist');
      expect(_switch(tester).selected, {MeasureSite.wrist});
      expect(find.text('على المعصم قد تحتاج أول قراءة حتى 25 ثانية'), findsOneWidget);
      expect(find.text('غير متاح على المعصم'), findsOneWidget, reason: 'SpO2 tile follows the profile');

      await tester.tap(find.descendant(of: find.byKey(ControlsPanel.profileKey), matching: find.text('الإصبع')));
      await tester.pump();
      expect(band.sent.last, 'f');
      await tearDownApp(tester, c);
    });

    testWidgets('demo recordings ignore commands: the switch is disabled', (tester) async {
      final c = await pumpApp(tester, transports: demo);
      await tester.tap(find.byKey(DevicesPage.connectKey));
      await tester.pump();
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(_switch(tester).onSelectionChanged, isNull);
      expect(_switch(tester).selected, {MeasureSite.finger}, reason: 'site of the recording');
      await tearDownApp(tester, c);
    });
  });

  group('guided measurement switches the profile first', () {
    testWidgets('finger: sends f, ignores readings until #MODE finger, then starts the timer', (tester) async {
      final factory = FakeTransportFactory();
      final c = await pumpApp(tester, transports: factory);
      final band = await _connect(tester, factory);
      await _openMeasure(tester);
      await _startMeasure(tester, MeasurePage.fingerKey);

      expect(band.sent.last, 'f');
      expect(find.byKey(MeasurePage.tuningKey), findsOneWidget);
      expect(find.text('جاري ضبط الحساس…'), findsOneWidget);
      await _send(tester, band, _m());
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(measureControllerProvider).step, MeasureStep.tuning, reason: 'old-profile readings ignored');

      await _send(tester, band, '#MODE finger');
      final state = c.read(measureControllerProvider);
      expect(state.step, MeasureStep.measuring);
      expect(state.remaining, const Duration(seconds: 75), reason: 'the timer starts at the #MODE line');
      expect(state.latest, isNull);
      expect(state.firmwareMismatch, isFalse);
      await tearDownApp(tester, c);
    });

    testWidgets('wrist on firmware v3.0: switches from finger, no mismatch notice', (tester) async {
      final factory = FakeTransportFactory();
      final c = await pumpApp(tester, transports: factory);
      final band = await _connect(tester, factory);
      await _send(tester, band, '#MODE finger'); // boot message: band starts in finger
      await _openMeasure(tester);
      await _startMeasure(tester, MeasurePage.wristKey);

      expect(band.sent.last, 'w');
      await _send(tester, band, '#MODE wrist');
      expect(c.read(measureControllerProvider).step, MeasureStep.measuring);
      expect(c.read(measureControllerProvider).firmwareMismatch, isFalse);
      expect(find.textContaining('ما زال في وضع'), findsNothing);

      // Contact but no heart rate yet: the wrist needs up to 25 s.
      await _send(tester, band, _m(bpm: -1, quality: 10));
      expect(find.text('على المعصم قد تحتاج أول قراءة حتى 25 ثانية'), findsOneWidget);
      await tearDownApp(tester, c);
    });

    testWidgets('older firmware without a reply: starts after 3 s and shows the notice', (tester) async {
      final factory = FakeTransportFactory();
      final c = await pumpApp(tester, transports: factory);
      final band = await _connect(tester, factory);
      await _send(tester, band, '#MODE finger');
      await _openMeasure(tester);
      await _startMeasure(tester, MeasurePage.wristKey);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(c.read(measureControllerProvider).step, MeasureStep.tuning);
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.read(measureControllerProvider).step, MeasureStep.measuring);
      expect(c.read(measureControllerProvider).firmwareMismatch, isTrue);
      await tester.pump();
      expect(find.textContaining('السوار ما زال في وضع الإصبع'), findsOneWidget);
      await tearDownApp(tester, c);
    });

    testWidgets('cancel while tuning: back to the instructions, the timer never starts', (tester) async {
      final factory = FakeTransportFactory();
      final c = await pumpApp(tester, transports: factory);
      await _connect(tester, factory);
      await _openMeasure(tester);
      await _startMeasure(tester, MeasurePage.fingerKey);

      await tester.tap(find.byKey(MeasurePage.cancelKey));
      await tester.pump();
      expect(c.read(measureControllerProvider).step, MeasureStep.instructions);
      await tester.pump(const Duration(seconds: 4));
      expect(c.read(measureControllerProvider).step, MeasureStep.instructions);
      await tearDownApp(tester, c);
    });

    testWidgets('disconnecting while tuning stops with the disconnect message', (tester) async {
      final factory = FakeTransportFactory();
      final c = await pumpApp(tester, transports: factory);
      final band = await _connect(tester, factory);
      await _openMeasure(tester);
      await _startMeasure(tester, MeasurePage.fingerKey);

      band.loseConnection();
      await tester.pump();
      await tester.pump();
      expect(c.read(measureControllerProvider).stoppedByDisconnect, isTrue);
      await tester.pump(const Duration(seconds: 4));
      expect(c.read(measureControllerProvider).step, MeasureStep.instructions);
      await tearDownApp(tester, c);
    });
  });
}
