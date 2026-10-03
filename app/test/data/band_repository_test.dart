import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/command_encoder.dart';
import 'package:repocare_band/features/band/data/repository/band_repository.dart';
import 'package:repocare_band/features/band/data/transport/band_transport.dart';
import 'package:repocare_band/features/band/data/transport/demo_recording.dart';
import 'package:repocare_band/features/band/data/transport/transport_factory.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';
import 'package:repocare_band/features/band/domain/enums.dart';

import '../support/fake_transport.dart';

void main() {
  late FakeTransportFactory factory;
  late BandRepository repo;

  setUp(() {
    factory = FakeTransportFactory();
    repo = BandRepository(transportFactory: factory);
  });

  tearDown(() => repo.dispose());

  test('parses lines into events and drops broken ones', () async {
    final events = <BandEvent>[];
    repo.events.listen(events.add);
    await repo.connect(const UsbSerialRequest());
    factory.last
      ..push('S,1,2,3.0')
      ..push('garbage')
      ..push('S,1,2')
      ..push('B,800');
    await pumpEventQueue();
    expect(events, [const SampleFrame(ir: 1, red: 2, ppg: 3), const BeatEvent(ibiMs: 800)]);
  });

  test('connection state follows the transport', () async {
    final states = <BandConnectionState>[];
    repo.connectionStates.listen(states.add);
    await repo.connect(const DemoRequest(DemoRecording.fingerRest));
    expect(repo.connectionState, BandConnectionState.connected);
    expect(repo.transport?.kind, TransportKind.demo);
    await repo.disconnect();
    await pumpEventQueue();
    expect(states, [
      BandConnectionState.connecting,
      BandConnectionState.connected,
      BandConnectionState.disconnected,
    ]);
    expect(repo.transport, isNull);
  });

  test('commands are encoded and only sent while connected', () async {
    await repo.send(BandCommand.reset);
    await repo.connect(const UsbSerialRequest());
    await repo.send(BandCommand.led3);
    await repo.send(BandCommand.autoLed);
    expect(factory.last.sent, ['3', 'a']);
  });

  test('a failed connect is rethrown and leaves nothing behind', () async {
    factory.onCreate = (t, _) =>
        t.connectError = const TransportFailure(TransportFailureCode.portBusy);
    await expectLater(
      repo.connect(const UsbSerialRequest()),
      throwsA(const TransportFailure(TransportFailureCode.portBusy)),
    );
    expect(repo.transport, isNull);
    expect(repo.connectionState, BandConnectionState.disconnected);
    expect(factory.last.isDisposed, isTrue);
  });

  test('connecting again replaces and disposes the previous transport', () async {
    await repo.connect(const UsbSerialRequest());
    final first = factory.last;
    await repo.connect(const DemoRequest(DemoRecording.wristBackRest));
    expect(first.isDisposed, isTrue);
    expect(repo.transport, same(factory.last));
  });

  test('lost connection is forwarded; reconnect uses the last request', () async {
    final failures = <TransportFailure>[];
    repo.failures.listen(failures.add);
    await repo.connect(const UsbSerialRequest());
    factory.last.loseConnection();
    await pumpEventQueue();
    expect(failures.single.code, TransportFailureCode.connectionLost);
    expect(failures.single.canReconnect, isTrue);
    expect(repo.connectionState, BandConnectionState.disconnected);

    await repo.reconnect();
    expect(factory.created, hasLength(2));
    expect(factory.last.kind, TransportKind.usbSerial);
    expect(factory.last.connectCalls, 1);
    expect(repo.connectionState, BandConnectionState.connected);
  });

  test('reconnect without a previous request is an error', () {
    expect(repo.reconnect, throwsStateError);
  });
}
