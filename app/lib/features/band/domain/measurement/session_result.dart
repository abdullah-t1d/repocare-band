import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Why a guided measurement ended.
enum SessionEndReason {
  /// The reading was stable long enough.
  stable,

  /// The maximum duration was reached.
  timeout,

  /// The user stopped it or the band disconnected.
  cancelled,
}

/// Outcome of a guided measurement.
@immutable
class SessionResult {
  const SessionResult({
    required this.site,
    required this.endReason,
    required this.startedAt,
    required this.duration,
    required this.readingsUsed,
    this.bpm,
    this.hrvMs,
    this.spo2,
    this.quality,
  });

  final MeasureSite site;
  final SessionEndReason endReason;
  final DateTime startedAt;
  final Duration duration;

  /// Number of one-second readings the values below are based on.
  final int readingsUsed;

  /// Median heart rate of the readings used; `null` when there was no reliable
  /// reading.
  final double? bpm;

  /// Median HRV (RMSSD), when the firmware reported one.
  final double? hrvMs;

  /// Median SpO2 estimate, fingertip only.
  final double? spo2;

  /// Median quality of the readings used.
  final int? quality;

  /// A heart rate was measured reliably.
  bool get isSuccess => bpm != null;

  bool get isCancelled => endReason == SessionEndReason.cancelled;

  @override
  String toString() => 'SessionResult(${site.name}, ${endReason.name}, '
      'bpm: $bpm, hrv: $hrvMs, spo2: $spo2, quality: $quality, '
      'readings: $readingsUsed, ${duration.inSeconds}s)';
}
