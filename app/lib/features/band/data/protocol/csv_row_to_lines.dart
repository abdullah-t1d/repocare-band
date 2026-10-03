import 'package:flutter/foundation.dart';

import '../../../../core/constants/band_constants.dart';

/// One row of a recording exported by the dashboard.
///
/// Columns are documented in `1_heart_rate/README.md#csv-columns`.
@immutable
class RecordingRow {
  const RecordingRow({
    required this.timeMs,
    required this.ir,
    required this.red,
    required this.ppg,
    required this.beat,
    required this.bpm,
    required this.spo2,
    required this.quality,
    required this.led,
    required this.contact,
    required this.pi,
    required this.motion,
    required this.ledMa,
  });

  /// Parses one data line, or returns `null` when it is malformed.
  static RecordingRow? tryParse(String line) {
    final p = line.trim().split(',');
    if (p.length != 13) return null;
    final timeMs = int.tryParse(p[0]);
    final ir = int.tryParse(p[1]);
    final red = int.tryParse(p[2]);
    final ppg = double.tryParse(p[3]);
    final bpm = double.tryParse(p[5]);
    final spo2 = double.tryParse(p[6]);
    final quality = int.tryParse(p[7]);
    final pi = double.tryParse(p[10]);
    final ledMa = double.tryParse(p[12]);
    final led = p[8];
    final ledOk = led == 'auto' || const ['1', '2', '3', '4'].contains(led);
    if (timeMs == null ||
        ir == null ||
        red == null ||
        ppg == null ||
        bpm == null ||
        spo2 == null ||
        quality == null ||
        pi == null ||
        ledMa == null ||
        !ledOk) {
      return null;
    }
    return RecordingRow(
      timeMs: timeMs,
      ir: ir,
      red: red,
      ppg: ppg,
      beat: p[4] == '1',
      bpm: bpm,
      spo2: spo2,
      quality: quality,
      led: led,
      contact: p[9] == '1',
      pi: pi,
      motion: p[11] == '1',
      ledMa: ledMa,
    );
  }

  final int timeMs;
  final int ir;
  final int red;
  final double ppg;
  final bool beat;
  final double bpm;
  final double spo2;
  final int quality;

  /// `auto` or `1`–`4`.
  final String led;
  final bool contact;
  final double pi;
  final bool motion;
  final double ledMa;

  /// Columns that come from the `M` line; they change about once per second.
  bool sameMetricsAs(RecordingRow o) =>
      bpm == o.bpm &&
      spo2 == o.spo2 &&
      quality == o.quality &&
      led == o.led &&
      contact == o.contact &&
      pi == o.pi &&
      motion == o.motion &&
      ledMa == o.ledMa;
}

/// Parses a whole recording. The header and malformed lines are skipped.
List<RecordingRow> parseRecording(String csv) => [
      for (final line in csv.split('\n'))
        if (RecordingRow.tryParse(line) case final row?) row,
    ];

/// Turns recording rows back into the protocol lines the firmware sent.
///
/// Per row, in the order the dashboard originally received them:
/// 1. an `M` line when the metric columns changed (that is when the real `M`
///    line arrived), and at least once every 100 rows;
/// 2. a `B` line when the row is marked as a beat;
/// 3. the `S` line.
///
/// The recordings do not contain every `M` field. Missing values are sent as
/// "not available" (RMSSD `-1`, chip temperature `-99`) so nothing is
/// invented; `saturated` is derived from IR like the firmware does, and the
/// stored-beat count is the number of beats since contact, capped at 12.
/// The beat interval is the time since the previous beat row; when that is
/// outside the firmware's 300–2000 ms range (a beat was rejected in between),
/// it is estimated from the reported heart rate.
class RecordingToLines {
  _RowCursorState _state = const _RowCursorState();

  /// Starts again from the beginning of a recording.
  void reset() => _state = const _RowCursorState();

  List<String> linesFor(RecordingRow row) {
    final s = _state;
    final lines = <String>[];

    var beats = row.contact ? s.beatsSinceContact : 0;
    if (row.beat && row.contact) beats++;

    final needsMetrics = s.previous == null ||
        !row.sameMetricsAs(s.previous!) ||
        s.rowsSinceMetrics >= BandConstants.sampleRateHz - 1;
    if (needsMetrics) lines.add(_metricsLine(row, beats));

    if (row.beat) lines.add('B,${_ibi(row, s.lastBeatTimeMs)}');

    lines.add('S,${row.ir},${row.red},${row.ppg.toStringAsFixed(1)}');

    _state = _RowCursorState(
      previous: row,
      rowsSinceMetrics: needsMetrics ? 0 : s.rowsSinceMetrics + 1,
      beatsSinceContact: beats,
      lastBeatTimeMs: row.beat ? row.timeMs : s.lastBeatTimeMs,
    );
    return lines;
  }

  String _metricsLine(RecordingRow r, int beats) {
    final auto = r.led == 'auto';
    final saturated = r.ir > BandConstants.saturationIr;
    final stored = beats > BandConstants.maxStoredBeats ? BandConstants.maxStoredBeats : beats;
    return [
      'M',
      r.bpm.toStringAsFixed(1),
      r.spo2.toStringAsFixed(1),
      '-1.0', // RMSSD is not in the recording
      r.contact ? '1' : '0',
      '${r.quality}',
      '-99', // chip temperature is not in the recording
      auto ? '0' : r.led,
      saturated ? '1' : '0',
      '$stored',
      r.pi.toStringAsFixed(2),
      r.motion ? '1' : '0',
      auto ? '1' : '0',
      r.ledMa.toStringAsFixed(1),
    ].join(',');
  }

  int _ibi(RecordingRow row, int? lastBeatTimeMs) {
    if (lastBeatTimeMs != null) {
      final diff = row.timeMs - lastBeatTimeMs;
      if (diff >= BandConstants.minIbiMs && diff <= BandConstants.maxIbiMs) return diff;
    }
    if (row.bpm > 0) {
      return (60000 / row.bpm).round().clamp(BandConstants.minIbiMs, BandConstants.maxIbiMs);
    }
    return 1000;
  }
}

/// Position-dependent state of [RecordingToLines].
@immutable
class _RowCursorState {
  const _RowCursorState({
    this.previous,
    this.rowsSinceMetrics = 0,
    this.beatsSinceContact = 0,
    this.lastBeatTimeMs,
  });

  final RecordingRow? previous;
  final int rowsSinceMetrics;
  final int beatsSinceContact;
  final int? lastBeatTimeMs;
}
