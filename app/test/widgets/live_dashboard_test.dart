import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/core/settings/app_settings.dart';
import 'package:repocare_band/features/band/presentation/pages/devices_page.dart';
import 'package:repocare_band/features/band/presentation/pages/live_page.dart';
import 'package:repocare_band/features/band/presentation/providers/band_providers.dart';
import 'package:repocare_band/features/band/presentation/providers/live_controller.dart';
import 'package:repocare_band/features/band/presentation/widgets/controls_panel.dart';
import 'package:repocare_band/features/band/presentation/widgets/demo_bar.dart';
import 'package:repocare_band/features/band/presentation/widgets/heart_rate_panel.dart';

import '../support/test_app.dart';

String _bpmText(WidgetTester tester) => tester.widget<Text>(find.byKey(HeartRatePanel.bpmKey)).data!;

void main() {
  late PreloadedDemoFactory demo;

  setUpAll(() async => demo = await PreloadedDemoFactory.load());

  testWidgets('finger recording drives the whole dashboard', (tester) async {
    final c = await pumpApp(tester, transports: demo);

    // Without Web Serial the demo is preselected with the finger recording.
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LivePage), findsOneWidget);
    expect(find.byType(DemoBar), findsOneWidget);

    await pumpFor(tester, const Duration(seconds: 5));

    final live = c.read(liveControllerProvider);
    expect(live.metrics, isNotNull);
    expect(live.beatCount, greaterThan(2), reason: '~70 bpm for 5 s');
    expect(live.trend, isNotEmpty);
    expect(c.read(connectionControllerProvider).status.firmwareMode?.name, 'finger');

    final bpm = int.parse(_bpmText(tester));
    expect(bpm, inInclusiveRange(60, 80));
    expect(find.text('طبيعي'), findsOneWidget, reason: 'normal zone');
    expect(find.text('ضمن المعتاد وقت الراحة'), findsOneWidget);
    // RMSSD and chip temperature are not in the recording: never shown as -1/-99.
    expect(find.text('-1'), findsNothing);
    expect(find.text('-99'), findsNothing);
    expect(find.text('-99.0'), findsNothing);

    await tearDownApp(tester, c);
  });

  testWidgets('demo controls: pause, restart, 2x', (tester) async {
    final c = await pumpApp(tester, transports: demo, prefs: {SettingsController.localeKey: 'en'});
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pump();
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 3));

    await tester.tap(find.byKey(DemoBar.pauseKey));
    await tester.pump();
    final paused = c.read(liveControllerProvider).beatCount;
    final pausedAt = c.read(demoPlaybackProvider).value!.position;
    await pumpFor(tester, const Duration(seconds: 3));
    expect(c.read(liveControllerProvider).beatCount, paused, reason: 'no beats while paused');
    expect(c.read(demoPlaybackProvider).value!.paused, isTrue);
    expect(c.read(demoPlaybackProvider).value!.position, pausedAt);

    await tester.tap(find.byKey(DemoBar.pauseKey)); // resume
    await tester.tap(find.text('2x'));
    await pumpFor(tester, const Duration(seconds: 2));
    final playback = c.read(demoPlaybackProvider).value!;
    expect(playback.speed, 2);
    expect(playback.position.inSeconds, inInclusiveRange(pausedAt.inSeconds + 3, pausedAt.inSeconds + 5));

    await tester.tap(find.byKey(DemoBar.restartKey));
    await tester.pump();
    expect(c.read(demoPlaybackProvider).value!.position, Duration.zero);

    await tearDownApp(tester, c);
  });

  testWidgets('recording to CSV can start and stop', (tester) async {
    final c = await pumpApp(tester, transports: demo, prefs: {SettingsController.localeKey: 'en'});
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.byKey(ControlsPanel.recordKey));
    await tester.pump(); // the scroll is laid out on the next frame
    await tester.tap(find.byKey(ControlsPanel.recordKey));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(c.read(liveControllerProvider).recording, isTrue);
    await tester.tap(find.byKey(ControlsPanel.recordKey));
    await tester.pump();
    final state = c.read(liveControllerProvider);
    expect(state.recording, isFalse);
    expect(state.canExport, isTrue);
    expect(c.read(csvRecorderProvider).rowCount, inInclusiveRange(180, 220));

    await tearDownApp(tester, c);
  });

  testWidgets('tablet width stacks the dashboard without overflow', (tester) async {
    final c = await pumpApp(tester, transports: demo, size: const Size(800, 1100));
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pump();
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, c);
  });

  testWidgets('phone width: demo bar and dashboard without overflow', (tester) async {
    final c = await pumpApp(tester, transports: demo, size: const Size(390, 844));
    await tester.ensureVisible(find.byKey(DevicesPage.connectKey));
    await tester.pump(); // the scroll is laid out on the next frame
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pump();
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.byType(DemoBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, c);
  });
}
