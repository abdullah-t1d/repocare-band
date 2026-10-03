import 'package:repocare_band/features/band/data/transport/band_transport.dart';
import 'package:repocare_band/features/band/data/transport/transport_factory.dart';
import 'package:repocare_band/features/band/domain/enums.dart';

/// Transport driven by the test: lines, failures and connect results are
/// pushed by hand.
class FakeTransport extends BandTransportBase {
  FakeTransport({this.kind = TransportKind.usbSerial, this.connectError});

  @override
  final TransportKind kind;

  /// Thrown by the next [connect] call, if set.
  TransportFailure? connectError;

  int connectCalls = 0;
  final List<String> sent = [];

  @override
  Future<void> connect() async {
    connectCalls++;
    setState(BandConnectionState.connecting);
    final error = connectError;
    if (error != null) {
      setState(BandConnectionState.disconnected);
      throw error;
    }
    setState(BandConnectionState.connected);
  }

  @override
  Future<void> disconnect() async => setState(BandConnectionState.disconnected);

  @override
  Future<void> send(String command) async => sent.add(command);

  void push(String line) => emitLine(line);

  /// Simulates an unplugged cable.
  void loseConnection() {
    setState(BandConnectionState.disconnected);
    reportFailure(const TransportFailure(TransportFailureCode.connectionLost));
  }
}

/// Hands out [FakeTransport]s and remembers them.
class FakeTransportFactory implements TransportFactory {
  FakeTransportFactory({this.isUsbSerialSupported = true, this.onCreate});

  @override
  bool isUsbSerialSupported;

  /// Lets a test configure each new transport (e.g. make connect fail).
  void Function(FakeTransport transport, TransportRequest request)? onCreate;

  final List<FakeTransport> created = [];

  FakeTransport get last => created.last;

  @override
  FakeTransport create(TransportRequest request) {
    final t = FakeTransport(kind: request.kind);
    onCreate?.call(t, request);
    created.add(t);
    return t;
  }
}
