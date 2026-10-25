import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/clock.dart';
import '../../data/repository/band_repository.dart';
import '../../data/transport/band_transport.dart';
import '../../data/transport/demo_replay_transport.dart';
import '../../data/transport/transport_factory.dart';
import '../../domain/band_event.dart';
import '../../domain/device_status.dart';
import '../../domain/enums.dart';

/// Current time; overridden in tests.
final nowProvider = Provider<Now>((ref) => systemNow);

/// Creates transports; overridden in tests with fakes.
final transportFactoryProvider =
    Provider<TransportFactory>((ref) => const DefaultTransportFactory());

final bandRepositoryProvider = Provider<BandRepository>((ref) {
  final repository = BandRepository(transportFactory: ref.watch(transportFactoryProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// Connection as the UI sees it: link state, what was requested, the last
/// problem and what the firmware told us about itself.
@immutable
class ConnectionUiState {
  const ConnectionUiState({
    this.status = const DeviceStatus(),
    this.request,
    this.failure,
    this.usbSupported = false,
  });

  final DeviceStatus status;

  /// Last connection request; kept after a disconnect so it can be retried.
  final TransportRequest? request;

  /// Problem to show, until dismissed or a new connection starts.
  final TransportFailure? failure;

  /// The browser offers Web Serial.
  final bool usbSupported;

  bool get isConnected => status.isConnected;
  bool get isConnecting => status.connection == BandConnectionState.connecting;
  bool get isDemo => request is DemoRequest;

  /// Body site the connected sketch is made for, when known: from `#MODE`
  /// or from the demo recording.
  MeasureSite? get site {
    final mode = status.firmwareMode;
    if (mode != null) return mode == FirmwareMode.finger ? MeasureSite.finger : MeasureSite.wrist;
    final r = request;
    return r is DemoRequest && isConnected ? r.recording.site : null;
  }

  ConnectionUiState copyWith({
    DeviceStatus? status,
    TransportRequest? request,
    TransportFailure? failure,
    bool clearFailure = false,
  }) =>
      ConnectionUiState(
        status: status ?? this.status,
        request: request ?? this.request,
        failure: clearFailure ? null : failure ?? this.failure,
        usbSupported: usbSupported,
      );
}

class ConnectionController extends Notifier<ConnectionUiState> {
  BandRepository get _repo => ref.read(bandRepositoryProvider);

  @override
  ConnectionUiState build() {
    final repo = ref.watch(bandRepositoryProvider);
    final subscriptions = [
      repo.connectionStates.listen((_) => _syncConnection()),
      repo.failures.listen((f) => state = state.copyWith(failure: f)),
      repo.events.listen((e) {
        if (e is DeviceLog) _onLog(e);
      }),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
    });
    return ConnectionUiState(
      usbSupported: repo.isUsbSerialSupported,
      status: DeviceStatus(connection: repo.connectionState),
    );
  }

  /// Connects; returns `true` on success. A failure is kept in the state.
  Future<bool> connect(TransportRequest request) async {
    state = state.copyWith(
      request: request,
      clearFailure: true,
      status: DeviceStatus(connection: BandConnectionState.connecting, transport: request.kind),
    );
    try {
      await _repo.connect(request);
      _syncConnection();
      return true;
    } on TransportFailure catch (f) {
      _syncConnection();
      state = f.isSilent ? state.copyWith(clearFailure: true) : state.copyWith(failure: f);
      return false;
    }
  }

  /// Tries the last request again. For USB this opens the port picker, so it
  /// must be called from a click.
  Future<bool> reconnect() async {
    final request = state.request;
    return request == null ? false : connect(request);
  }

  Future<void> disconnect() async {
    await _repo.disconnect();
    state = state.copyWith(clearFailure: true);
    _syncConnection();
  }

  void dismissFailure() => state = state.copyWith(clearFailure: true);

  void _syncConnection() {
    final connection = _repo.connectionState;
    if (connection == state.status.connection) return;
    state = state.copyWith(
      status: connection == BandConnectionState.disconnected
          // Firmware details belong to the old link.
          ? DeviceStatus(transport: state.status.transport)
          : state.status.copyWith(connection: connection, transport: state.request?.kind),
    );
  }

  void _onLog(DeviceLog log) {
    final status = state.status;
    // The wiring hint is about the pulse sensor. The combined firmware also
    // reports the AS6221 (`#ERR AS6221 not found`, `#OK AS6221 ready`), which
    // must neither raise nor clear it.
    final aboutPulseSensor = log.text.contains('MAX30102');
    switch (log.kind) {
      case LogKind.mode:
        state = state.copyWith(status: status.copyWith(firmwareMode: log.firmwareMode));
      case LogKind.error:
        if (aboutPulseSensor) state = state.copyWith(status: status.copyWith(sensorError: true));
      case LogKind.ok:
        if (aboutPulseSensor) state = state.copyWith(status: status.copyWith(sensorError: false));
      case LogKind.boot ||
            LogKind.channel ||
            LogKind.led ||
            LogKind.reset ||
            LogKind.info:
        break;
    }
  }
}

final connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionUiState>(ConnectionController.new);

/// The demo transport while a recording is playing, otherwise `null`.
final demoTransportProvider = Provider<DemoReplayTransport?>((ref) {
  ref.watch(connectionControllerProvider.select((s) => s.status.connection));
  final transport = ref.watch(bandRepositoryProvider).transport;
  return transport is DemoReplayTransport ? transport : null;
});

/// Position and controls of the demo playback.
final demoPlaybackProvider = StreamProvider<DemoPlayback?>((ref) async* {
  final transport = ref.watch(demoTransportProvider);
  if (transport == null) {
    yield null;
    return;
  }
  yield transport.playback;
  yield* transport.playbackChanges;
});
