import 'package:flutter/foundation.dart';

import '../../domain/enums.dart';
import 'band_transport.dart';
import 'ble_transport.dart';
import 'demo_recording.dart';
import 'demo_replay_transport.dart';
import 'serial_support.dart';

/// What the user asked to connect to.
@immutable
sealed class TransportRequest {
  const TransportRequest();

  TransportKind get kind;
}

final class UsbSerialRequest extends TransportRequest {
  const UsbSerialRequest();

  @override
  TransportKind get kind => TransportKind.usbSerial;

  @override
  bool operator ==(Object other) => other is UsbSerialRequest;

  @override
  int get hashCode => kind.hashCode;
}

final class DemoRequest extends TransportRequest {
  const DemoRequest(this.recording);

  final DemoRecording recording;

  @override
  TransportKind get kind => TransportKind.demo;

  @override
  bool operator ==(Object other) => other is DemoRequest && other.recording == recording;

  @override
  int get hashCode => Object.hash(kind, recording);
}

final class BleRequest extends TransportRequest {
  const BleRequest();

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  bool operator ==(Object other) => other is BleRequest;

  @override
  int get hashCode => kind.hashCode;
}

/// Creates transports; replaced by a fake in tests.
abstract interface class TransportFactory {
  bool get isUsbSerialSupported;

  BandTransport create(TransportRequest request);
}

class DefaultTransportFactory implements TransportFactory {
  const DefaultTransportFactory();

  @override
  bool get isUsbSerialSupported => isWebSerialSupported();

  @override
  BandTransport create(TransportRequest request) => switch (request) {
        UsbSerialRequest() => createUsbSerialTransport(),
        DemoRequest(:final recording) => DemoReplayTransport(recording: recording),
        BleRequest() => BleTransport(),
      };
}
