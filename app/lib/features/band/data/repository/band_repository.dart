import 'dart:async';

import '../../domain/band_event.dart';
import '../../domain/enums.dart';
import '../protocol/command_encoder.dart';
import '../protocol/line_parser.dart';
import '../transport/band_transport.dart';
import '../transport/transport_factory.dart';

/// Single entry point to the band for the rest of the app.
///
/// Owns the current [BandTransport], turns its lines into [BandEvent]s and
/// forwards connection changes and failures. Only one transport is active at
/// a time; connecting again replaces it.
class BandRepository {
  BandRepository({
    required TransportFactory transportFactory,
    LineParser parser = const LineParser(),
    CommandEncoder encoder = const CommandEncoder(),
  })  : _factory = transportFactory,
        _parser = parser,
        _encoder = encoder;

  final TransportFactory _factory;
  final LineParser _parser;
  final CommandEncoder _encoder;

  final StreamController<BandEvent> _events = StreamController<BandEvent>.broadcast();
  final StreamController<BandConnectionState> _states =
      StreamController<BandConnectionState>.broadcast();
  final StreamController<TransportFailure> _failures =
      StreamController<TransportFailure>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  BandTransport? _transport;
  TransportRequest? _lastRequest;
  BandConnectionState _state = BandConnectionState.disconnected;

  /// Decoded lines from the band. Broken lines are dropped by the parser.
  Stream<BandEvent> get events => _events.stream;

  Stream<BandConnectionState> get connectionStates => _states.stream;

  /// Failures after a successful connection (e.g. cable unplugged).
  Stream<TransportFailure> get failures => _failures.stream;

  BandConnectionState get connectionState => _state;

  /// Transport in use, or `null`. Exposed for transport-specific controls
  /// such as the demo playback.
  BandTransport? get transport => _transport;

  /// Last request passed to [connect], used by [reconnect].
  TransportRequest? get lastRequest => _lastRequest;

  bool get isUsbSerialSupported => _factory.isUsbSerialSupported;

  /// Connects with a new transport. Throws [TransportFailure].
  Future<void> connect(TransportRequest request) async {
    await disconnect();
    _lastRequest = request;
    final transport = _factory.create(request);
    _attach(transport);
    _setState(BandConnectionState.connecting);
    try {
      await transport.connect();
      _setState(transport.state);
    } on Object {
      await _release(transport);
      _setState(BandConnectionState.disconnected);
      rethrow;
    }
  }

  /// Connects again with the last request, e.g. after the cable was
  /// unplugged. For USB this opens the port picker again.
  Future<void> reconnect() {
    final request = _lastRequest;
    if (request == null) throw StateError('Nothing to reconnect to');
    return connect(request);
  }

  Future<void> disconnect() async {
    final transport = _transport;
    if (transport == null) return;
    await _release(transport);
    _setState(BandConnectionState.disconnected);
  }

  /// Sends [command]; ignored while disconnected.
  Future<void> send(BandCommand command) async {
    final transport = _transport;
    if (transport == null || transport.state != BandConnectionState.connected) return;
    await transport.send(_encoder.encode(command));
  }

  Future<void> dispose() async {
    await disconnect();
    await Future.wait([_events.close(), _states.close(), _failures.close()]);
  }

  void _attach(BandTransport transport) {
    _transport = transport;
    _subscriptions.addAll([
      transport.lines.listen((line) {
        final event = _parser.parse(line);
        if (event != null && !_events.isClosed) _events.add(event);
      }),
      // Read the current state rather than the event value: events are
      // delivered later and may be stale by then.
      transport.states.listen((_) {
        if (identical(_transport, transport)) _setState(transport.state);
      }),
      transport.failures.listen((f) {
        if (!_failures.isClosed) _failures.add(f);
      }),
    ]);
  }

  Future<void> _release(BandTransport transport) async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    if (identical(_transport, transport)) _transport = null;
    await transport.dispose();
  }

  void _setState(BandConnectionState state) {
    if (state == _state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}
