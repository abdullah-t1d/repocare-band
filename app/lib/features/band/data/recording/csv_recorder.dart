import '../../../../core/utils/clock.dart';
import '../../domain/band_event.dart';
import '../../domain/enums.dart';

/// Records the live stream as CSV, with the same columns and file names as
/// the prototype dashboard (`1_heart_rate/README.md#csv-columns`), so files
/// from both tools can be analysed the same way.
///
/// One row is written per `S` line. The metric columns repeat the last `M`
/// line; `beat` is `1` on the first sample after a `B` line.
class CsvRecorder {
  CsvRecorder({Now now = systemNow}) : _now = now;

  static const String header =
      'time_ms,ir,red,ppg,beat,bpm,spo2,quality,led,contact,pi,motion,led_mA';

  final Now _now;
  final List<String> _rows = [];
  bool _recording = false;
  bool _pendingBeat = false;
  Metrics? _lastMetrics;

  bool get isRecording => _recording;

  /// Rows recorded so far (header excluded).
  int get rowCount => _rows.length;

  /// A finished recording is available for export.
  bool get canExport => !_recording && _rows.isNotEmpty;

  /// Starts a new recording, discarding the previous one.
  void start() {
    _rows.clear();
    _recording = true;
  }

  void stop() => _recording = false;

  /// Feed every event, also while not recording, so the first row already
  /// carries the latest metrics.
  void onEvent(BandEvent event) {
    switch (event) {
      case SampleFrame():
        if (_recording) _rows.add(_row(event));
        _pendingBeat = false;
      case BeatEvent():
        _pendingBeat = true;
      case Metrics():
        _lastMetrics = event;
      case DeviceLog():
        break;
    }
  }

  /// Header plus all rows, separated by `\n` (no trailing newline).
  String toCsv() => [header, ..._rows].join('\n');

  /// `repocare_<led>_<YYYY-MM-DD-HH-MM-SS>.csv`, time in UTC, as in the
  /// prototype.
  String fileName() {
    final t = _now().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}-${two(t.month)}-${two(t.day)}-'
        '${two(t.hour)}-${two(t.minute)}-${two(t.second)}';
    return 'repocare_${(_lastMetrics?.ledMode ?? LedMode.auto).csvLabel}_$stamp.csv';
  }

  String _row(SampleFrame s) {
    final m = _lastMetrics;
    return [
      _now().millisecondsSinceEpoch,
      s.ir,
      s.red,
      s.ppg.toStringAsFixed(1),
      _pendingBeat ? 1 : 0,
      formatCsvNumber(m?.bpm ?? -1),
      formatCsvNumber(m?.spo2 ?? -1),
      m?.quality ?? 0,
      (m?.ledMode ?? LedMode.auto).csvLabel,
      (m?.contact ?? false) ? 1 : 0,
      formatCsvNumber(m?.perfusionIndex ?? -1),
      (m?.motion ?? false) ? 1 : 0,
      formatCsvNumber(m?.ledCurrentMa ?? 0),
    ].join(',');
  }
}

/// Formats a number the way JavaScript does (`70.3`, `-1`, `6.2`), which is
/// what the prototype dashboard wrote.
String formatCsvNumber(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
