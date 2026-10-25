import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/enums.dart';

/// Why a transport could not connect or lost its connection.
///
/// The presentation layer turns each code into a localised message; the
/// transports never produce user-facing text themselves.
enum TransportFailureCode {
  /// The browser has no Web Serial API (not Chrome or Edge on a computer).
  unsupportedBrowser,

  /// The user closed the port picker without choosing a port.
  noPortSelected,

  /// The port is already open in another program, usually the Arduino
  /// Serial Monitor or another browser tab.
  portBusy,

  /// The port could not be opened for another reason.
  openFailed,

  /// The connection dropped: cable unplugged or board reset after an upload.
  connectionLost,

  /// A demo recording could not be loaded.
  recordingUnavailable,

  /// The transport exists in the interface but is not built yet (BLE).
  notImplemented,
}

/// Error raised by [BandTransport.connect] and published on
/// [BandTransport.failures].
@immutable
class TransportFailure implements Exception {
  const TransportFailure(this.code, [this.detail]);

  final TransportFailureCode code;

  /// Technical detail for logs (browser error text). Never shown as the main
  /// message.
  final String? detail;

  /// Picking the port again may fix the problem.
  bool get canReconnect =>
      code == TransportFailureCode.connectionLost ||
      code == TransportFailureCode.portBusy ||
      code == TransportFailureCode.openFailed;

  /// The user cancelled on purpose; no message is needed.
  bool get isSilent => code == TransportFailureCode.noPortSelected;

  @override
  bool operator ==(Object other) =>
      other is TransportFailure && other.code == code && other.detail == detail;

  @override
  int get hashCode => Object.hash(code, detail);

  @override
  String toString() => 'TransportFailure(${code.name}${detail == null ? '' : ': $detail'})';
}

/// A link to the band that delivers the text lines of
/// `docs/SERIAL_PROTOCOL.md` and accepts single-character commands.
///
/// Everything above this interface (parser, repository, UI) is the same for
/// USB, the demo replay and the future BLE link.
abstract interface class BandTransport {
  TransportKind get kind;

  BandConnectionState get state;

  /// Changes of [state].
  Stream<BandConnectionState> get states;

  /// Complete lines without the line ending, in arrival order.
  Stream<String> get lines;

  /// Problems that happen after [connect] succeeded, such as an unplugged
  /// cable. Problems during [connect] are thrown instead.
  Stream<TransportFailure> get failures;

  /// Opens the link. Throws [TransportFailure].
  Future<void> connect();

  /// Closes the link. Safe to call in any state.
  Future<void> disconnect();

  /// Sends a command. Does nothing when not connected.
  Future<void> send(String command);

  /// Disconnects and releases all resources. The transport cannot be reused.
  Future<void> dispose();
}

/// Stream plumbing shared by all transports.
abstract class BandTransportBase implements BandTransport {
  final StreamController<String> _lines = StreamController<String>.broadcast();
  final StreamController<BandConnectionState> _states =
      StreamController<BandConnectionState>.broadcast();
  final StreamController<TransportFailure> _failures =
      StreamController<TransportFailure>.broadcast();
  BandConnectionState _state = BandConnectionState.disconnected;
  bool _disposed = false;

  @override
  BandConnectionState get state => _state;

  @override
  Stream<BandConnectionState> get states => _states.stream;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Stream<TransportFailure> get failures => _failures.stream;

  bool get isDisposed => _disposed;

  @protected
  void setState(BandConnectionState value) {
    if (value == _state) return;
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  @protected
  void emitLine(String line) {
    if (!_lines.isClosed) _lines.add(line);
  }

  @protected
  void reportFailure(TransportFailure failure) {
    if (!_failures.isClosed) _failures.add(failure);
  }

  @override
  @mustCallSuper
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    // Not awaited: the futures only report that the done event reached the
    // listeners, which nothing depends on.
    unawaited(_lines.close());
    unawaited(_states.close());
    unawaited(_failures.close());
  }
}
