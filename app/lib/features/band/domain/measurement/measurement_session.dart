import 'dart:math' as math;

import '../../../../core/utils/stats.dart';
import '../band_event.dart';
import '../enums.dart';
import 'measure_protocol.dart';
import 'session_result.dart';

/// Logic of one guided measurement, independent of timers and widgets.
///
/// The caller feeds every `M` line with [addMetrics] and calls [tick]
/// regularly; both take the time elapsed since the start, so tests can drive
/// the session without waiting.
///
/// * **HRV received** ([MeasureProtocol.endsOnHrv], fingertip): ends at the
///   first `M` line with skin contact and a valid RMSSD. Heart rate and SpO2
///   are the medians of all readings at [MeasureProtocol.goodQuality] or
///   better; HRV is the firmware's value as received.
/// * **Early stop** (wrist): readings at [MeasureProtocol.stableQuality] or
///   better, without a break, for [MeasureProtocol.stableWindow]. The result
///   is the median of that stable part.
/// * **Timeout:** at [MeasureProtocol.maxDuration] the result is the median of
///   all readings at [MeasureProtocol.goodQuality] or better, if there are at
///   least [MeasureProtocol.minGoodReadings] of them. Otherwise no heart rate
///   is reported.
///
/// `#MODE` is only a hint: it is printed once at start-up, so it is often never
/// received. A mismatch is reported through [firmwareMismatch] and never stops
/// or fails the measurement.
class MeasurementSession {
  MeasurementSession({required this.protocol, required this.startedAt});

  /// Each `M` line summarises the second before it.
  static const Duration readingPeriod = Duration(seconds: 1);

  /// A longer silence between `M` lines breaks a stable streak.
  static const Duration maxReadingGap = Duration(milliseconds: 2500);

  final MeasureProtocol protocol;
  final DateTime startedAt;

  final List<_Reading> _good = [];
  final List<_Reading> _streak = [];
  Duration _elapsed = Duration.zero;
  Duration? _lastReadingAt;
  Metrics? _latest;
  FirmwareMode? _reportedFirmware;
  SessionResult? _result;

  Duration get elapsed => _elapsed;

  /// Progress towards [MeasureProtocol.maxDuration], 0–1.
  double get progress => math.min(1, _elapsed.inMilliseconds / protocol.maxDuration.inMilliseconds);

  Duration get remaining {
    final left = protocol.maxDuration - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Most recent `M` line received during the session.
  Metrics? get latest => _latest;

  /// How long the current stable streak has lasted.
  Duration get stableFor => _streak.isEmpty
      ? Duration.zero
      : _streak.last.at - _streak.first.at + readingPeriod;

  /// Progress of the current stable streak towards an early stop, 0–1; always
  /// 0 when the protocol has no early stop.
  double get stableProgress {
    final window = protocol.stableWindow;
    return window == null ? 0 : math.min(1, stableFor.inMilliseconds / window.inMilliseconds);
  }

  /// A `#MODE` line arrived and names the other sketch.
  bool get firmwareMismatch =>
      _reportedFirmware != null && _reportedFirmware != protocol.site.expectedFirmware;

  bool get isFinished => _result != null;

  /// Set once the session has ended.
  SessionResult? get result => _result;

  void addMetrics(Metrics metrics, Duration elapsed) {
    if (isFinished) return;
    _advance(elapsed);
    _latest = metrics;

    final gapBroken = _lastReadingAt != null && elapsed - _lastReadingAt! > maxReadingGap;
    _lastReadingAt = elapsed;
    final reading = _Reading(metrics, elapsed);

    if (_isUsable(metrics, protocol.goodQuality)) _good.add(reading);

    final hrv = metrics.rmssdMs;
    if (protocol.endsOnHrv && metrics.contact && hrv != null) {
      _finish(SessionEndReason.hrvReceived, _enoughGood, hrvMs: hrv);
      return;
    }

    final stableQuality = protocol.stableQuality;
    final stableWindow = protocol.stableWindow;
    if (stableQuality != null && stableWindow != null) {
      if (_isUsable(metrics, stableQuality)) {
        if (gapBroken) _streak.clear();
        _streak.add(reading);
        if (stableFor >= stableWindow) {
          _finish(SessionEndReason.stable, _streak);
          return;
        }
      } else {
        _streak.clear();
      }
    }

    _checkTimeout();
  }

  /// Advances the clock; ends the session when the time is up.
  void tick(Duration elapsed) {
    if (isFinished) return;
    _advance(elapsed);
    _checkTimeout();
  }

  void onDeviceLog(DeviceLog log) {
    if (log.firmwareMode != null) _reportedFirmware = log.firmwareMode;
  }

  /// Stops the session without a result.
  void cancel(Duration elapsed) {
    if (isFinished) return;
    _advance(elapsed);
    _result = SessionResult(
      site: protocol.site,
      endReason: SessionEndReason.cancelled,
      startedAt: startedAt,
      duration: _elapsed,
      readingsUsed: 0,
    );
  }

  void _advance(Duration elapsed) {
    if (elapsed > _elapsed) _elapsed = elapsed;
  }

  /// Good readings, or none when there are too few for a reliable result.
  List<_Reading> get _enoughGood => _good.length >= protocol.minGoodReadings ? _good : const [];

  void _checkTimeout() {
    if (_elapsed < protocol.maxDuration) return;
    _finish(SessionEndReason.timeout, _enoughGood);
  }

  bool _isUsable(Metrics m, int minQuality) =>
      m.contact && !m.saturated && !m.motion && m.bpm != null && m.quality >= minQuality;

  /// [hrvMs] is the value that ended an [MeasureProtocol.endsOnHrv] session.
  /// Such a session never averages per-second RMSSD values: on timeout it has
  /// no HRV.
  void _finish(SessionEndReason reason, List<_Reading> readings, {double? hrvMs}) {
    final metrics = [for (final r in readings) r.metrics];
    final quality = median([for (final m in metrics) m.quality.toDouble()]);
    _result = SessionResult(
      site: protocol.site,
      endReason: reason,
      startedAt: startedAt,
      duration: _elapsed,
      readingsUsed: metrics.length,
      bpm: median([for (final m in metrics) m.bpm!]),
      hrvMs: protocol.endsOnHrv
          ? hrvMs
          : median([for (final m in metrics) if (m.rmssdMs != null) m.rmssdMs!]),
      spo2: protocol.reportsSpo2
          ? median([for (final m in metrics) if (m.spo2 != null) m.spo2!])
          : null,
      quality: quality?.round(),
    );
  }
}

class _Reading {
  const _Reading(this.metrics, this.at);

  final Metrics metrics;
  final Duration at;
}
