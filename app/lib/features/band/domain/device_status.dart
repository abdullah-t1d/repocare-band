import 'package:flutter/foundation.dart';

import 'enums.dart';

/// Everything the UI needs to know about the link to the band, apart from
/// the measurements themselves.
@immutable
class DeviceStatus {
  const DeviceStatus({
    this.connection = BandConnectionState.disconnected,
    this.transport,
    this.firmwareMode,
    this.sensorError = false,
  });

  final BandConnectionState connection;

  /// Transport in use, or `null` before the first connection.
  final TransportKind? transport;

  /// Sketch reported by `#MODE`. Usually `null`: the line is printed once at
  /// start-up, often before the browser connects.
  final FirmwareMode? firmwareMode;

  /// The firmware reported `#ERR` (sensor not found) and no `#OK` since.
  final bool sensorError;

  bool get isConnected => connection == BandConnectionState.connected;

  DeviceStatus copyWith({
    BandConnectionState? connection,
    TransportKind? transport,
    FirmwareMode? firmwareMode,
    bool? sensorError,
  }) =>
      DeviceStatus(
        connection: connection ?? this.connection,
        transport: transport ?? this.transport,
        firmwareMode: firmwareMode ?? this.firmwareMode,
        sensorError: sensorError ?? this.sensorError,
      );

  @override
  bool operator ==(Object other) =>
      other is DeviceStatus &&
      other.connection == connection &&
      other.transport == transport &&
      other.firmwareMode == firmwareMode &&
      other.sensorError == sensorError;

  @override
  int get hashCode => Object.hash(connection, transport, firmwareMode, sensorError);
}
