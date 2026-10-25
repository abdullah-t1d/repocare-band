import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/protocol/command_encoder.dart';
import '../../domain/band_event.dart';
import '../../domain/enums.dart';
import '../../domain/live_assessment.dart';
import '../../domain/measurement/measure_protocol.dart';
import '../../domain/measurement/measurement_session.dart';
import '../../domain/measurement/session_result.dart';
import 'band_providers.dart';

/// Screens of the guided measurement, in order. [tuning]: the profile command
/// was sent and the app waits for the firmware's matching `#MODE` line.
enum MeasureStep { choose, instructions, tuning, measuring, result }

/// What the measure page shows. While measuring, the fields mirror the
/// running [MeasurementSession]; [history] lives for the browser session only.
@immutable
class MeasureState {
  const MeasureState({
    this.step = MeasureStep.choose,
    this.site,
    this.progress = 0,
    this.remaining = Duration.zero,
    this.latest,
    this.hrvSteadySeconds = 0,
    this.stableProgress = 0,
    this.firmwareMismatch = false,
    this.result,
    this.history = const [],
    this.stoppedByDisconnect = false,
  });

  final MeasureStep step;
  final MeasureSite? site;

  /// Progress towards the maximum duration, 0–1.
  final double progress;
  final Duration remaining;

  /// Last `M` line of the running measurement.
  final Metrics? latest;

  /// Consecutive seconds with quality ≥ 45 in this measurement, see
  /// [nextHrvSteadySeconds].
  final int hrvSteadySeconds;

  /// Wrist: progress of the stable streak towards an early stop, 0–1.
  final double stableProgress;

  /// A `#MODE` line names the other sketch.
  final bool firmwareMismatch;

  /// Set on the result screen.
  final SessionResult? result;

  /// Finished measurements, newest first. Cancelled ones are not kept.
  final List<SessionResult> history;

  /// The last measurement stopped because the band disconnected.
  final bool stoppedByDisconnect;

  MeasureProtocol? get protocol => site == null ? null : MeasureProtocol.forSite(site!);
}

/// Runs guided measurements on the connected band.
///
/// On start it sends `f` or `w` (firmware v3.0 switches profile and replies
/// `#MODE finger|wrist`) and starts the timer only once the matching `#MODE`
/// line arrives, so no reading of the other profile is used. Older firmware
/// ignores the command: after [modeSwitchTimeout] the measurement starts
/// anyway and a known mismatching mode shows the firmware notice. Demo
/// recordings ignore commands and start at once.
///
/// Time comes from `package:clock`, so widget tests can drive a whole
/// measurement with fake time.
class MeasureController extends Notifier<MeasureState> {
  /// How often the remaining time is refreshed between `M` lines.
  static const Duration tickInterval = Duration(milliseconds: 250);

  /// How long to wait for the `#MODE` reply before starting anyway.
  static const Duration modeSwitchTimeout = Duration(seconds: 3);

  MeasurementSession? _session;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  Timer? _tuneTimer;
  int _steadySeconds = 0;

  @override
  MeasureState build() {
    final repo = ref.watch(bandRepositoryProvider);
    final subscriptions = [
      repo.events.listen(_onEvent),
      repo.connectionStates.listen(_onConnection),
    ];
    ref.onDispose(() {
      _timer?.cancel();
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
    });
    return const MeasureState();
  }

  /// Shows the instructions for [site].
  void choose(MeasureSite site) =>
      state = MeasureState(step: MeasureStep.instructions, site: site, history: state.history);

  /// Back to the mode choice; a running measurement is dropped.
  void backToChoice() {
    _stop(cancel: true);
    state = MeasureState(history: state.history);
  }

  /// Same mode again, from its instructions.
  void measureAgain() {
    final site = state.site;
    state = site == null
        ? MeasureState(history: state.history)
        : MeasureState(step: MeasureStep.instructions, site: site, history: state.history);
  }

  void start() {
    final site = state.site;
    if (site == null) return;
    _stop(cancel: true);
    final conn = ref.read(connectionControllerProvider);
    if (conn.isDemo) {
      _begin(null);
      return;
    }
    state = MeasureState(step: MeasureStep.tuning, site: site, history: state.history);
    unawaited(ref.read(bandRepositoryProvider).send(BandCommand.forSite(site)));
    _tuneTimer = Timer(
      modeSwitchTimeout,
      () => _begin(ref.read(connectionControllerProvider).status.firmwareMode),
    );
  }

  /// Starts the timed session. [knownMode] is the firmware profile known at
  /// this point, for the mismatch notice.
  void _begin(FirmwareMode? knownMode) {
    _tuneTimer?.cancel();
    _tuneTimer = null;
    final protocol = state.protocol;
    if (protocol == null) return;
    _startedAt = clock.now();
    final session = MeasurementSession(protocol: protocol, startedAt: _startedAt);
    if (knownMode != null) session.reportFirmware(knownMode);
    _session = session;
    _steadySeconds = 0;
    _timer = Timer.periodic(tickInterval, (_) => _tick());
    _publish();
  }

  /// Stops the running measurement without a result.
  void cancel() {
    _stop(cancel: true);
    measureAgain();
  }

  void clearHistory() => state = MeasureState(
        step: state.step,
        site: state.site,
        progress: state.progress,
        remaining: state.remaining,
        latest: state.latest,
        hrvSteadySeconds: state.hrvSteadySeconds,
        stableProgress: state.stableProgress,
        firmwareMismatch: state.firmwareMismatch,
        result: state.result,
        stoppedByDisconnect: state.stoppedByDisconnect,
      );

  Duration get _elapsed => clock.now().difference(_startedAt);

  void _onEvent(BandEvent event) {
    if (state.step == MeasureStep.tuning) {
      // Readings of the old profile are ignored; the matching #MODE starts the timer.
      final mode = event is DeviceLog ? event.firmwareMode : null;
      if (mode != null && mode == state.site?.expectedFirmware) _begin(mode);
      return;
    }
    final session = _session;
    if (session == null) return;
    switch (event) {
      case Metrics():
        _steadySeconds = nextHrvSteadySeconds(_steadySeconds, event);
        session.addMetrics(event, _elapsed);
        _publish();
      case DeviceLog():
        session.onDeviceLog(event);
        _publish();
      case SampleFrame() || BeatEvent():
        break;
    }
  }

  void _tick() {
    final session = _session;
    if (session == null) return;
    session.tick(_elapsed);
    _publish();
  }

  void _onConnection(BandConnectionState connection) {
    final running = _session != null || state.step == MeasureStep.tuning;
    if (connection != BandConnectionState.disconnected || !running) return;
    _stop(cancel: true);
    state = MeasureState(
      step: MeasureStep.instructions,
      site: state.site,
      history: state.history,
      stoppedByDisconnect: true,
    );
  }

  void _stop({required bool cancel}) {
    _tuneTimer?.cancel();
    _tuneTimer = null;
    _timer?.cancel();
    _timer = null;
    if (cancel) _session?.cancel(_elapsed);
    _session = null;
  }

  void _publish() {
    final session = _session;
    if (session == null) return;
    final result = session.result;
    if (result != null) {
      _stop(cancel: false);
      state = MeasureState(
        step: MeasureStep.result,
        site: state.site,
        result: result,
        history: [result, ...state.history],
      );
      return;
    }
    state = MeasureState(
      step: MeasureStep.measuring,
      site: state.site,
      progress: session.progress,
      remaining: session.remaining,
      latest: session.latest,
      hrvSteadySeconds: _steadySeconds,
      stableProgress: session.stableProgress,
      firmwareMismatch: session.firmwareMismatch,
      history: state.history,
    );
  }
}

final measureControllerProvider =
    NotifierProvider<MeasureController, MeasureState>(MeasureController.new);
