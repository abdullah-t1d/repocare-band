import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/band_constants.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/file_saver.dart';
import '../../data/protocol/command_encoder.dart';
import '../../data/recording/csv_recorder.dart';
import '../../domain/band_event.dart';
import '../../domain/enums.dart';
import '../../domain/live_assessment.dart';
import 'band_providers.dart';
import 'waveform_buffer.dart';

/// One point of the heart-rate trend chart.
@immutable
class TrendPoint {
  const TrendPoint(this.time, this.bpm);

  final DateTime time;
  final double bpm;
}

/// Everything on the live dashboard that changes about once per second.
/// The 100 Hz waveform lives in [WaveformBuffer].
@immutable
class LiveState {
  const LiveState({
    this.metrics,
    this.beatCount = 0,
    this.lastIbiMs,
    this.hrvSteadySeconds = 0,
    this.trend = const [],
    this.logs = const [],
    this.channel,
    this.recording = false,
    this.recordedRows = 0,
    this.canExport = false,
  });

  /// Last `M` line.
  final Metrics? metrics;

  /// Beats received; the heart icon pulses when it changes.
  final int beatCount;

  final int? lastIbiMs;

  /// Consecutive seconds with quality ≥ 45, see [nextHrvSteadySeconds].
  final int hrvSteadySeconds;

  /// Heart rate over the last two minutes, oldest first. Held values are
  /// left out: they repeat an earlier reading.
  final List<TrendPoint> trend;

  /// Last device messages, newest first.
  final List<String> logs;

  /// Wrist sketch: signal used for the rhythm search.
  final PpgChannel? channel;

  final bool recording;
  final int recordedRows;
  final bool canExport;

  LiveState copyWith({
    Metrics? metrics,
    int? beatCount,
    int? lastIbiMs,
    int? hrvSteadySeconds,
    List<TrendPoint>? trend,
    List<String>? logs,
    PpgChannel? channel,
    bool? recording,
    int? recordedRows,
    bool? canExport,
  }) =>
      LiveState(
        metrics: metrics ?? this.metrics,
        beatCount: beatCount ?? this.beatCount,
        lastIbiMs: lastIbiMs ?? this.lastIbiMs,
        hrvSteadySeconds: hrvSteadySeconds ?? this.hrvSteadySeconds,
        trend: trend ?? this.trend,
        logs: logs ?? this.logs,
        channel: channel ?? this.channel,
        recording: recording ?? this.recording,
        recordedRows: recordedRows ?? this.recordedRows,
        canExport: canExport ?? this.canExport,
      );
}

final waveformProvider = Provider<WaveformBuffer>((ref) {
  final buffer = WaveformBuffer();
  ref.onDispose(buffer.dispose);
  return buffer;
});

final csvRecorderProvider = Provider<CsvRecorder>((ref) => CsvRecorder(now: ref.watch(nowProvider)));

/// Feeds the live dashboard from the band and runs its commands.
class LiveController extends Notifier<LiveState> {
  late WaveformBuffer _waveform;
  late CsvRecorder _recorder;
  late Now _now;

  @override
  LiveState build() {
    final repo = ref.watch(bandRepositoryProvider);
    _waveform = ref.watch(waveformProvider);
    _recorder = ref.watch(csvRecorderProvider);
    _now = ref.watch(nowProvider);
    final subscriptions = [
      repo.events.listen(_onEvent),
      repo.connectionStates.listen(_onConnection),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
    });
    return const LiveState();
  }

  Future<void> setLed(LedMode mode) =>
      ref.read(bandRepositoryProvider).send(BandCommand.forLedMode(mode));

  /// Restarts the firmware analysis and clears the trend, like the prototype.
  Future<void> resetAnalysis() async {
    await ref.read(bandRepositoryProvider).send(BandCommand.reset);
    state = state.copyWith(trend: const []);
  }

  void toggleRecording() {
    if (_recorder.isRecording) {
      _recorder.stop();
    } else {
      _recorder.start();
    }
    _syncRecorder();
  }

  /// Downloads the recording as CSV (same columns as the prototype).
  void exportCsv() {
    if (!_recorder.canExport) return;
    saveTextFile(_recorder.fileName(), _recorder.toCsv());
  }

  void _onEvent(BandEvent event) {
    _recorder.onEvent(event);
    switch (event) {
      case SampleFrame():
        _waveform.addSample(event);
      case BeatEvent():
        _waveform.markBeat();
        state = state.copyWith(beatCount: state.beatCount + 1, lastIbiMs: event.ibiMs);
      case Metrics():
        state = state.copyWith(
          metrics: event,
          hrvSteadySeconds: nextHrvSteadySeconds(state.hrvSteadySeconds, event),
          trend: _updatedTrend(isHeldHeartRate(event) ? null : event.bpm),
          recordedRows: _recorder.rowCount,
        );
      case DeviceLog():
        state = state.copyWith(
          logs: [event.text, ...state.logs].take(BandConstants.maxLogLines).toList(),
          channel: event.channel,
        );
    }
  }

  void _onConnection(BandConnectionState connection) {
    if (connection != BandConnectionState.disconnected) return;
    // Like the prototype: values disappear with the link. A recording that
    // was running is stopped and stays available for export.
    _recorder.stop();
    _waveform.clear();
    state = LiveState(
      logs: state.logs,
      recordedRows: _recorder.rowCount,
      canExport: _recorder.canExport,
    );
  }

  List<TrendPoint> _updatedTrend(double? bpm) {
    final now = _now();
    final cutoff = now.subtract(BandConstants.trendWindow);
    return [
      for (final p in state.trend)
        if (p.time.isAfter(cutoff)) p,
      if (bpm != null) TrendPoint(now, bpm),
    ];
  }

  void _syncRecorder() => state = state.copyWith(
        recording: _recorder.isRecording,
        recordedRows: _recorder.rowCount,
        canExport: _recorder.canExport,
      );
}

final liveControllerProvider = NotifierProvider<LiveController, LiveState>(LiveController.new);
