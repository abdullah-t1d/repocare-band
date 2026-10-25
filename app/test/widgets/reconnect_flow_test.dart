import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/core/settings/app_settings.dart';
import 'package:repocare_band/features/band/data/transport/band_transport.dart';
import 'package:repocare_band/features/band/domain/enums.dart';
import 'package:repocare_band/features/band/presentation/pages/devices_page.dart';
import 'package:repocare_band/features/band/presentation/pages/live_page.dart';
import 'package:repocare_band/features/band/presentation/providers/band_providers.dart';
import 'package:repocare_band/features/band/presentation/widgets/connection_widgets.dart';

import '../support/fake_transport.dart';
import '../support/test_app.dart';

const _en = {SettingsController.localeKey: 'en'};

void main() {
  testWidgets('unplugged cable: message, Reconnect opens the picker again', (tester) async {
    final factory = FakeTransportFactory();
    final c = await pumpApp(tester, transports: factory, prefs: _en);

    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pumpAndSettle();
    expect(find.byType(LivePage), findsOneWidget);
    expect(c.read(connectionControllerProvider).isConnected, isTrue);

    factory.last.loseConnection();
    await tester.pumpAndSettle();
    expect(find.textContaining('connection to the band was lost'), findsOneWidget);
    expect(find.byKey(ConnectionBanner.reconnectKey), findsOneWidget);
    expect(find.text('Band not connected'), findsOneWidget);

    await tester.tap(find.byKey(ConnectionBanner.reconnectKey));
    await tester.pumpAndSettle();
    expect(factory.created, hasLength(2), reason: 'a new USB transport, so a new port picker');
    expect(factory.last.kind, TransportKind.usbSerial);
    expect(c.read(connectionControllerProvider).isConnected, isTrue);
    expect(find.byKey(ConnectionBanner.reconnectKey), findsNothing);
    await tearDownApp(tester, c);
  });

  testWidgets('busy port: clear message and a retry button', (tester) async {
    final factory = FakeTransportFactory(
      onCreate: (t, _) => t.connectError = const TransportFailure(TransportFailureCode.portBusy),
    );
    final c = await pumpApp(tester, transports: factory, prefs: _en);

    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pumpAndSettle();
    expect(find.text('Close Arduino Serial Monitor or any other page connected to the band.'),
        findsOneWidget);
    expect(find.byType(DevicesPage), findsOneWidget, reason: 'stays on the devices page');

    factory.onCreate = null; // Serial Monitor closed
    await tester.tap(find.byKey(ConnectionBanner.reconnectKey));
    await tester.pumpAndSettle();
    expect(c.read(connectionControllerProvider).isConnected, isTrue);
    await tearDownApp(tester, c);
  });

  testWidgets('closing the port picker shows no error', (tester) async {
    final factory = FakeTransportFactory(
      onCreate: (t, _) =>
          t.connectError = const TransportFailure(TransportFailureCode.noPortSelected),
    );
    final c = await pumpApp(tester, transports: factory, prefs: _en);
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pumpAndSettle();
    expect(c.read(connectionControllerProvider).failure, isNull);
    expect(find.byKey(ConnectionBanner.reconnectKey), findsNothing);
    await tearDownApp(tester, c);
  });

  testWidgets('unsupported browser: Arabic notice, demo preselected', (tester) async {
    final c = await pumpApp(tester, transports: FakeTransportFactory(isUsbSerialSupported: false));
    expect(find.text('افتح الموقع في Chrome أو Edge على الكمبيوتر'), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-fingerRest')), findsOneWidget);
    await tearDownApp(tester, c);
  });

  testWidgets('#ERR shows the wiring hint until #OK', (tester) async {
    final factory = FakeTransportFactory();
    final c = await pumpApp(tester, transports: factory, prefs: _en);
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pumpAndSettle();

    factory.last.push('#ERR MAX30102 not found - check wiring: Blue SDA=D4, Yellow SCL=D5');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensor not found'), findsOneWidget);

    factory.last.push('#OK MAX30102 ready');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensor not found'), findsNothing);
    await tearDownApp(tester, c);
  });

  testWidgets('AS6221 messages neither raise nor clear the pulse-sensor hint', (tester) async {
    final factory = FakeTransportFactory();
    final c = await pumpApp(tester, transports: factory, prefs: _en);
    await tester.tap(find.byKey(DevicesPage.connectKey));
    await tester.pumpAndSettle();

    // Combined firmware v2.2 with the skin-temperature sensor unplugged.
    factory.last.push('#OK MAX30102 ready');
    factory.last.push('#ERR AS6221 not found at 0x48');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensor not found'), findsNothing);

    factory.last.push('#ERR MAX30102 lost - retrying');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensor not found'), findsOneWidget);
    factory.last.push('#OK AS6221 ready');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensor not found'), findsOneWidget, reason: 'only the MAX30102 OK clears it');
    factory.last.push('#OK MAX30102 ready');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sensor not found'), findsNothing);
    await tearDownApp(tester, c);
  });
}
