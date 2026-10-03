import 'package:flutter/foundation.dart';

import 'enums.dart';

/// One decoded line from the band. See `docs/SERIAL_PROTOCOL.md`.
///
/// The class is sealed so a `switch` over events is checked for completeness.
@immutable
sealed class BandEvent {
  const BandEvent();
}

/// `S,<ir>,<red>,<ppg>`: one raw sample, 100 per second.
final class SampleFrame extends BandEvent {
  const SampleFrame({required this.ir, required this.red, required this.ppg});

  /// Raw 18-bit infrared value.
  final int ir;

  /// Raw 18-bit red value.
  final int red;

  /// Filtered pulse wave; `0` while there is no skin contact.
  final double ppg;

  @override
  bool operator ==(Object other) =>
      other is SampleFrame && other.ir == ir && other.red == red && other.ppg == ppg;

  @override
  int get hashCode => Object.hash(ir, red, ppg);

  @override
  String toString() => 'SampleFrame(ir: $ir, red: $red, ppg: $ppg)';
}

/// `B,<ibi_ms>`: a beat accepted by the firmware.
final class BeatEvent extends BandEvent {
  const BeatEvent({required this.ibiMs});

  /// Time since the previous accepted beat, in milliseconds.
  final int ibiMs;

  @override
  bool operator ==(Object other) => other is BeatEvent && other.ibiMs == ibiMs;

  @override
  int get hashCode => ibiMs.hashCode;

  @override
  String toString() => 'BeatEvent(ibiMs: $ibiMs)';
}

/// `M,...`: results computed by the firmware, once per second.
///
/// "Not available" values (`-1`, `-99`) are mapped to `null` by the parser, so
/// the UI can never show them as numbers.
final class Metrics extends BandEvent {
  const Metrics({
    required this.contact,
    required this.quality,
    required this.ledMode,
    required this.saturated,
    required this.storedBeats,
    required this.motion,
    this.bpm,
    this.spo2,
    this.rmssdMs,
    this.chipTempC,
    this.perfusionIndex,
    this.ledCurrentMa,
  });

  /// Heart rate in beats per minute.
  final double? bpm;

  /// SpO2 estimate in %, uncalibrated, finger sketch only.
  final double? spo2;

  /// HRV (RMSSD) in milliseconds.
  final double? rmssdMs;

  /// Skin detected under the sensor.
  final bool contact;

  /// Signal quality, 0–100.
  final int quality;

  /// Temperature of the MAX30102 chip itself, **not** body temperature.
  final double? chipTempC;

  final LedMode ledMode;

  /// The signal is clipped (LED too bright for the ADC range).
  final bool saturated;

  /// Clean beats currently stored by the firmware (0–12).
  final int storedBeats;

  /// Perfusion index (pulse strength), %.
  final double? perfusionIndex;

  /// Movement detected (always `false` while the IMU is off).
  final bool motion;

  /// LED current in mA.
  final double? ledCurrentMa;

  @override
  bool operator ==(Object other) =>
      other is Metrics &&
      other.bpm == bpm &&
      other.spo2 == spo2 &&
      other.rmssdMs == rmssdMs &&
      other.contact == contact &&
      other.quality == quality &&
      other.chipTempC == chipTempC &&
      other.ledMode == ledMode &&
      other.saturated == saturated &&
      other.storedBeats == storedBeats &&
      other.perfusionIndex == perfusionIndex &&
      other.motion == motion &&
      other.ledCurrentMa == ledCurrentMa;

  @override
  int get hashCode => Object.hash(bpm, spo2, rmssdMs, contact, quality, chipTempC,
      ledMode, saturated, storedBeats, perfusionIndex, motion, ledCurrentMa);

  @override
  String toString() => 'Metrics(bpm: $bpm, spo2: $spo2, rmssd: $rmssdMs, '
      'contact: $contact, quality: $quality, temp: $chipTempC, led: ${ledMode.name}, '
      'saturated: $saturated, beats: $storedBeats, pi: $perfusionIndex, '
      'motion: $motion, ledMa: $ledCurrentMa)';
}

/// `#<text>`: status or error message.
final class DeviceLog extends BandEvent {
  const DeviceLog({
    required this.text,
    required this.kind,
    this.firmwareMode,
    this.channel,
  });

  /// Message without the leading `#`.
  final String text;

  final LogKind kind;

  /// Set for `#MODE finger` / `#MODE wrist`.
  final FirmwareMode? firmwareMode;

  /// Set for `#CH IR` / `#CH RED` / `#CH MIX`.
  final PpgChannel? channel;

  @override
  bool operator ==(Object other) =>
      other is DeviceLog &&
      other.text == text &&
      other.kind == kind &&
      other.firmwareMode == firmwareMode &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(text, kind, firmwareMode, channel);

  @override
  String toString() => 'DeviceLog(${kind.name}: $text)';
}
