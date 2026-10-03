import '../../domain/enums.dart';
import 'band_transport.dart';

/// Bluetooth Low Energy link for the future wireless firmware.
///
/// Not built yet; it exists so the interface, the factory and the UI already
/// have a place for it.
///
/// ## Design note
///
/// * Package: `flutter_blue_plus`, which uses Web Bluetooth in Chrome and Edge
///   (and native BLE on Android/iOS when the module moves into the team's
///   mobile app).
/// * The firmware should expose the Nordic UART Service
///   (`6e400001-b5a3-f393-e0a9-e50e24dcca9e`): notifications on the TX
///   characteristic carry the same text lines as USB, and the RX
///   characteristic accepts the same single-character commands. The parser,
///   repository and UI then work unchanged.
/// * BLE notifications are small (20–244 bytes), so lines arrive in pieces:
///   feed them through `LineAssembler`, exactly like the USB transport.
/// * 100 `S` lines per second (~2 KB/s) fit in BLE, but the firmware may send
///   `S` lines at a lower rate over BLE to save battery; the waveform only
///   needs ~25 per second.
/// * `connect` must run from a click (Web Bluetooth needs a user gesture) and
///   filter on the service UUID so only repoCare bands appear in the picker.
///
/// TODO(phase-2-ble): implement with flutter_blue_plus once the BLE firmware
/// exists.
class BleTransport extends BandTransportBase {
  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Future<void> connect() async =>
      throw const TransportFailure(TransportFailureCode.notImplemented);

  @override
  Future<void> disconnect() async => setState(BandConnectionState.disconnected);

  @override
  Future<void> send(String command) async {}
}
