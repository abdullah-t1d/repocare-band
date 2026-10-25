import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/core/settings/app_settings.dart';
import 'package:repocare_band/core/theme/app_palette.dart';
import 'package:repocare_band/features/band/presentation/pages/devices_page.dart';
import 'package:repocare_band/features/band/presentation/providers/live_controller.dart';
import 'package:repocare_band/features/band/presentation/widgets/beating_heart.dart';
import 'package:repocare_band/features/band/presentation/widgets/heart_rate_panel.dart';
import 'package:repocare_band/features/band/presentation/widgets/metric_tiles.dart';

import '../support/fake_transport.dart';
import '../support/test_app.dart';

/// An `M` line as firmware v2.2 sends it (-1 = not available); 72 BPM at quality 85 by default.
String _mLine({double bpm = 72, double spo2 = 97, double rmssd = -1, int contact = 1, int quality = 85}) =>
    'M,$bpm,$spo2,$rmssd,$contact,$quality,33.1,0,0,8,2.10,0,1,6.2';

/// Connects over a fake USB transport and returns it, on the live page.
Future<FakeTransport> _connect(WidgetTester tester, FakeTransportFactory factory) async {
  await tester.tap(find.byKey(DevicesPage.connectKey));
  await tester.pumpAndSettle();
  return factory.last;
}

Future<void> _send(WidgetTester tester, FakeTransport band, String line) async {
  band.push(line);
  await tester.pump();
}

/// Sends a beat and returns the heart's scale 60 ms into its pulse. The event
/// reaches the widget one frame after the line, so the pulse starts there.
Future<double> _beatScale(WidgetTester tester, FakeTransport band) async {
  await _send(tester, band, 'B,830');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  return _heartScale(tester);
}

String _bpmText(WidgetTester tester) => tester.widget<Text>(find.byKey(HeartRatePanel.bpmKey)).data!;

double _heartScale(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(BeatingHeart.iconKey)).transform.getMaxScaleOnAxis();

void main() {
  testWidgets('held BPM: greyed out as "last reading", heart stops beating', (tester) async {
    final factory = FakeTransportFactory();
    final c = await pumpApp(tester, transports: factory);
    final band = await _connect(tester, factory);

    // Live reading: zone colour, beating heart, no "last reading" label.
    await _send(tester, band, _mLine());
    await pumpFor(tester, const Duration(seconds: 1));
    expect(_bpmText(tester), '72');
    expect(find.byKey(HeartRatePanel.heldKey), findsNothing);
    expect(await _beatScale(tester, band), greaterThan(1.05), reason: 'live beats pulse the heart');
    await pumpFor(tester, const Duration(seconds: 1));

    // v2.2 holds the last good BPM while the signal drops: bpm > 0, quality < 40.
    await _send(tester, band, _mLine(quality: 30));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(_bpmText(tester), '72', reason: 'the number stays');
    expect(find.byKey(HeartRatePanel.heldKey), findsOneWidget);
    expect(find.text('آخر قراءة'), findsOneWidget);
    final muted = tester.element(find.byType(HeartRatePanel)).palette.muted;
    expect(tester.widget<Text>(find.byKey(HeartRatePanel.bpmKey)).style?.color, muted, reason: 'greyed out');
    expect(find.text('طبيعي'), findsNothing, reason: 'no zone for a held value');

    expect(await _beatScale(tester, band), 1.0, reason: 'no heart-beat animation while held');
    expect(c.read(liveControllerProvider).trend, hasLength(1), reason: 'held values stay out of the trend');

    // Quality 40 is live again.
    await _send(tester, band, _mLine(bpm: 74, quality: 40));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(_bpmText(tester), '74');
    expect(find.byKey(HeartRatePanel.heldKey), findsNothing);
    expect(c.read(liveControllerProvider).trend, hasLength(2));

    await tearDownApp(tester, c);
  });

  testWidgets('HRV: waiting message and steady-seconds progress until RMSSD arrives', (tester) async {
    final factory = FakeTransportFactory();
    final c = await pumpApp(tester, transports: factory);
    final band = await _connect(tester, factory);
    LinearProgressIndicator bar() => tester.widget<LinearProgressIndicator>(
        find.descendant(of: find.byKey(MetricTiles.hrvProgressKey), matching: find.byType(LinearProgressIndicator)));

    for (var i = 0; i < 15; i++) {
      await _send(tester, band, _mLine(quality: 80));
    }
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(MetricTiles.hrvWaitingKey), findsOneWidget);
    expect(find.text('يحتاج دقيقة ثبات'), findsOneWidget);
    expect(find.text('15 من 60 ث'), findsOneWidget);
    expect(bar().value, closeTo(0.25, 0.01));
    expect(c.read(liveControllerProvider).hrvSteadySeconds, 15);

    // One weak second (quality < 45) restarts the count.
    await _send(tester, band, _mLine(quality: 44));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('0 من 60 ث'), findsOneWidget);

    // Past 60 s the tile shows a full bar but never more than 60.
    for (var i = 0; i < 70; i++) {
      await _send(tester, band, _mLine(quality: 80));
    }
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('60 من 60 ث'), findsOneWidget);
    expect(bar().value, 1.0);

    // The firmware's RMSSD replaces the waiting state.
    await _send(tester, band, _mLine(quality: 80, rmssd: 51.3));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(MetricTiles.hrvWaitingKey), findsNothing);
    expect(find.text('51'), findsOneWidget);

    // No contact: plain "--", no waiting message.
    await _send(tester, band, _mLine(bpm: -1, spo2: -1, contact: 0, quality: 0));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(MetricTiles.hrvWaitingKey), findsNothing);

    await tearDownApp(tester, c);
  });

  testWidgets('English labels', (tester) async {
    final factory = FakeTransportFactory();
    final c = await pumpApp(tester, transports: factory, prefs: {SettingsController.localeKey: 'en'});
    final band = await _connect(tester, factory);
    await _send(tester, band, _mLine(bpm: 70, quality: 20));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Last reading'), findsOneWidget);
    expect(find.text('Needs 1 minute of stillness'), findsOneWidget);
    expect(find.text('0 of 60 s'), findsOneWidget);
    await tearDownApp(tester, c);
  });
}
