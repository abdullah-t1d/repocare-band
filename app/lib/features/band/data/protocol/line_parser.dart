import '../../../../core/constants/band_constants.dart';
import '../../domain/band_event.dart';
import '../../domain/enums.dart';

/// Decodes one text line from the band into a [BandEvent].
///
/// Implements `docs/SERIAL_PROTOCOL.md`. The parser is deliberately tolerant:
/// a serial stream can start in the middle of a line, and a cable can be pulled
/// mid-transfer, so any broken, partial or unknown line returns `null`. It
/// never throws.
class LineParser {
  const LineParser();

  /// Fields in an `M` line (prefix included) in the current firmware.
  static const int metricsFieldCount = 14;

  /// Fields in an `M` line from the first firmware version, which did not yet
  /// send `pi`, `motion`, `auto` and `led_mA`. Still accepted.
  static const int metricsMinFieldCount = 10;

  BandEvent? parse(String line) {
    final text = line.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('#')) return _log(text.substring(1).trim());
    final parts = text.split(',');
    return switch (parts.first) {
      'S' => _sample(parts),
      'B' => _beat(parts),
      'M' => _metrics(parts),
      _ => null,
    };
  }

  SampleFrame? _sample(List<String> p) {
    if (p.length != 4) return null;
    final ir = _adc(p[1]);
    final red = _adc(p[2]);
    final ppg = _finite(p[3]);
    if (ir == null || red == null || ppg == null) return null;
    return SampleFrame(ir: ir, red: red, ppg: ppg);
  }

  BeatEvent? _beat(List<String> p) {
    if (p.length != 2) return null;
    final ibi = int.tryParse(p[1]);
    // The firmware never sends an interval above MAX_IBI.
    if (ibi == null || ibi <= 0 || ibi > BandConstants.maxIbiMs) return null;
    return BeatEvent(ibiMs: ibi);
  }

  Metrics? _metrics(List<String> p) {
    // Any other length means the line was cut off or glued to another line.
    if (p.length != metricsFieldCount && p.length != metricsMinFieldCount) return null;
    final full = p.length == metricsFieldCount;

    final bpm = _finite(p[1]);
    final spo2 = _finite(p[2]);
    final rmssd = _finite(p[3]);
    final contact = _flag(p[4]);
    final quality = int.tryParse(p[5]);
    final temp = _finite(p[6]);
    final led = int.tryParse(p[7]);
    final saturated = _flag(p[8]);
    final beats = int.tryParse(p[9]);
    if (bpm == null ||
        spo2 == null ||
        rmssd == null ||
        contact == null ||
        quality == null ||
        temp == null ||
        led == null ||
        led < 0 ||
        led > 4 ||
        saturated == null ||
        beats == null ||
        beats < 0) {
      return null;
    }

    final pi = full ? _finite(p[10]) : -1.0;
    final motion = full ? _flag(p[11]) : false;
    final auto = full ? _flag(p[12]) : led == 0;
    final ledMa = full ? _finite(p[13]) : -1.0;
    if (pi == null || motion == null || auto == null || ledMa == null) return null;

    final LedMode ledMode;
    if (auto || led == 0) {
      ledMode = LedMode.auto;
    } else {
      final fixed = LedMode.fixed(led);
      if (fixed == null) return null;
      ledMode = fixed;
    }

    return Metrics(
      bpm: bpm > 0 ? bpm : null,
      spo2: spo2 > 0 ? spo2 : null,
      rmssdMs: rmssd >= 0 ? rmssd : null,
      contact: contact,
      quality: quality.clamp(0, 100),
      chipTempC: temp > -90 ? temp : null,
      ledMode: ledMode,
      saturated: saturated,
      storedBeats: beats,
      perfusionIndex: pi >= 0 ? pi : null,
      motion: motion,
      ledCurrentMa: ledMa > 0 ? ledMa : null,
    );
  }

  DeviceLog? _log(String text) {
    // Drop control characters that appear when the board resets mid-line.
    final clean = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (clean.isEmpty) return null;

    if (clean == 'BOOT') return DeviceLog(text: clean, kind: LogKind.boot);
    if (clean.startsWith('OK')) return DeviceLog(text: clean, kind: LogKind.ok);
    if (clean.startsWith('ERR')) return DeviceLog(text: clean, kind: LogKind.error);
    if (clean.startsWith('LED')) return DeviceLog(text: clean, kind: LogKind.led);
    if (clean == 'Reset') return DeviceLog(text: clean, kind: LogKind.reset);

    final mode = switch (clean) {
      'MODE finger' => FirmwareMode.finger,
      'MODE wrist' => FirmwareMode.wrist,
      _ => null,
    };
    if (mode != null) return DeviceLog(text: clean, kind: LogKind.mode, firmwareMode: mode);

    final channel = switch (clean) {
      'CH IR' => PpgChannel.ir,
      'CH RED' => PpgChannel.red,
      'CH MIX' => PpgChannel.mix,
      _ => null,
    };
    if (channel != null) return DeviceLog(text: clean, kind: LogKind.channel, channel: channel);

    return DeviceLog(text: clean, kind: LogKind.info);
  }

  /// Raw 18-bit ADC value.
  int? _adc(String s) {
    final v = int.tryParse(s);
    return v != null && v >= 0 && v <= BandConstants.adcMax ? v : null;
  }

  double? _finite(String s) {
    final v = double.tryParse(s);
    return v != null && v.isFinite ? v : null;
  }

  bool? _flag(String s) => switch (s) {
        '1' => true,
        '0' => false,
        _ => null,
      };
}
