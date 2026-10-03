import '../../domain/enums.dart';
import 'band_transport.dart';

/// Outside the browser (unit tests, other platforms) there is no Web Serial.
bool isWebSerialSupported() => false;

BandTransport createUsbSerialTransport() => _UnsupportedSerialTransport();

class _UnsupportedSerialTransport extends BandTransportBase {
  @override
  TransportKind get kind => TransportKind.usbSerial;

  @override
  Future<void> connect() async =>
      throw const TransportFailure(TransportFailureCode.unsupportedBrowser);

  @override
  Future<void> disconnect() async => setState(BandConnectionState.disconnected);

  @override
  Future<void> send(String command) async {}
}
