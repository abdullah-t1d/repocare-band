import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';
import 'package:repocare_band/features/band/domain/enums.dart';
import 'package:repocare_band/features/band/domain/measurement/measure_protocol.dart';
import 'package:repocare_band/features/band/domain/measurement/measurement_session.dart';
import 'package:repocare_band/features/band/domain/measurement/session_result.dart';

final DateTime _start = DateTime(2026, 10, 3, 10);

Metrics _m({
  double? bpm = 70,
  int quality = 90,
  bool contact = true,
  bool motion = false,
  bool saturated = false,
  double? rmssd,
  double? spo2,
}) =>
    Metrics(
      bpm: bpm,
      spo2: spo2,
      rmssdMs: rmssd,
      contact: contact,
      quality: quality,
      ledMode: LedMode.auto,
      saturated: saturated,
      storedBeats: 8,
      motion: motion,
    );

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

MeasurementSession _session(MeasureProtocol p) => MeasurementSession(protocol: p, startedAt: _start);

/// Feeds one reading per second starting at [from] seconds.
void _feed(MeasurementSession s, List<Metrics> readings, {num from = 1}) {
  for (var i = 0; i < readings.length; i++) {
    s.addMetrics(readings[i], _s(from + i));
  }
}

void main() {
  group('protocols', () {
    test('finger: 30 s, quality 75 for 8 s', () {
      const p = MeasureProtocol.finger;
      expect(p.maxDuration, const Duration(seconds: 30));
      expect(p.stableQuality, 75);
      expect(p.stableWindow, const Duration(seconds: 8));
      expect(p.reportsSpo2, isTrue);
    });

    test('wrist: 60 s, quality 60 for 10 s, no SpO2', () {
      const p = MeasureProtocol.wrist;
      expect(p.maxDuration, const Duration(seconds: 60));
      expect(p.stableQuality, 60);
      expect(p.stableWindow, const Duration(seconds: 10));
      expect(p.reportsSpo2, isFalse);
    });
  });

  group('early stop', () {
    test('finger stops after 8 s of quality >= 75 with the median of that part', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, [_m(bpm: 90, quality: 40), _m(bpm: 88, quality: 50)]); // settling
      final bpms = <double>[70, 72, 71, 69, 73, 70, 71, 72];
      _feed(s, [for (final b in bpms) _m(bpm: b, quality: 80, rmssd: 40, spo2: 97)], from: 3);

      expect(s.isFinished, isTrue);
      final r = s.result!;
      expect(r.endReason, SessionEndReason.stable);
      expect(r.isSuccess, isTrue);
      expect(r.bpm, 71); // median of the stable part only, not of 90/88
      expect(r.hrvMs, 40);
      expect(r.spo2, 97);
      expect(r.quality, 80);
      expect(r.readingsUsed, 8);
      expect(r.duration, _s(10));
      expect(r.startedAt, _start);
    });

    test('7 stable seconds are not enough', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(7, _m(quality: 80)));
      expect(s.isFinished, isFalse);
      expect(s.stableFor, _s(7));
      expect(s.stableProgress, closeTo(7 / 8, 1e-9));
    });

    test('a weak reading restarts the stable part', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, [
        ...List.filled(6, _m(quality: 80)),
        _m(quality: 74),
        ...List.filled(7, _m(quality: 80)),
      ]);
      expect(s.isFinished, isFalse);
      s.addMetrics(_m(quality: 80), _s(15));
      expect(s.result?.endReason, SessionEndReason.stable);
      expect(s.result?.readingsUsed, 8);
    });

    test('motion, saturation, lost contact or missing BPM break the stable part', () {
      for (final bad in [
        _m(motion: true),
        _m(saturated: true),
        _m(contact: false),
        _m(bpm: null),
      ]) {
        final s = _session(MeasureProtocol.finger);
        _feed(s, [...List.filled(7, _m()), bad]);
        expect(s.stableFor, Duration.zero, reason: '$bad');
        expect(s.isFinished, isFalse);
      }
    });

    test('a gap of more than 2.5 s between readings restarts the stable part', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(5, _m()));
      _feed(s, List.filled(3, _m()), from: 9); // 4 s silence after t=5
      expect(s.isFinished, isFalse);
      expect(s.stableFor, _s(3));
    });

    test('wrist accepts quality 60 and needs 10 s', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(9, _m(quality: 60, spo2: 95)));
      expect(s.isFinished, isFalse);
      s.addMetrics(_m(quality: 60, spo2: 95), _s(10));
      expect(s.result?.endReason, SessionEndReason.stable);
      expect(s.result?.spo2, isNull, reason: 'SpO2 is finger only');
    });

    test('quality 60 is not enough on the finger', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(20, _m(quality: 60)));
      expect(s.isFinished, isFalse);
    });
  });

  group('timeout', () {
    test('with at least 5 good readings: median of the good readings', () {
      final s = _session(MeasureProtocol.finger);
      // Quality 50 is "good" (>= 45) but never "stable" (>= 75).
      _feed(s, [
        _m(bpm: 60, quality: 50),
        _m(bpm: 62, quality: 50),
        _m(bpm: 64, quality: 50),
        _m(bpm: 66, quality: 50),
        _m(bpm: 68, quality: 50),
        _m(bpm: 150, quality: 30), // weak, ignored
        _m(bpm: 140, contact: false), // no contact, ignored
      ]);
      s.tick(_s(29.9));
      expect(s.isFinished, isFalse);
      s.tick(_s(30));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.timeout);
      expect(r.isSuccess, isTrue);
      expect(r.bpm, 64);
      expect(r.readingsUsed, 5);
      expect(r.quality, 50);
      expect(r.hrvMs, isNull);
      expect(r.duration, _s(30));
    });

    test('with fewer than 5 good readings: no reliable reading', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, [
        ...List.filled(4, _m(quality: 50)),
        ...List.filled(20, _m(quality: 20)),
      ]);
      s.tick(_s(30));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.timeout);
      expect(r.isSuccess, isFalse);
      expect(r.bpm, isNull);
      expect(r.spo2, isNull);
      expect(r.hrvMs, isNull);
      expect(r.quality, isNull);
      expect(r.readingsUsed, 0);
    });

    test('no readings at all (e.g. inner wrist): no reliable reading after 60 s', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(59, _m(bpm: null, quality: 0)));
      expect(s.isFinished, isFalse);
      s.tick(_s(60));
      expect(s.result?.isSuccess, isFalse);
    });

    test('a reading that arrives after the time is up also ends the session', () {
      final s = _session(MeasureProtocol.finger);
      s.addMetrics(_m(quality: 10), _s(31));
      expect(s.result?.endReason, SessionEndReason.timeout);
    });
  });

  group('session state', () {
    test('progress and remaining time', () {
      final s = _session(MeasureProtocol.finger);
      expect(s.progress, 0);
      expect(s.remaining, _s(30));
      s.tick(_s(15));
      expect(s.progress, 0.5);
      expect(s.remaining, _s(15));
      s.tick(_s(10)); // time never goes back
      expect(s.elapsed, _s(15));
      s.tick(_s(45));
      expect(s.progress, 1);
      expect(s.remaining, Duration.zero);
    });

    test('latest reading is exposed for the live quality display', () {
      final s = _session(MeasureProtocol.finger);
      expect(s.latest, isNull);
      s.addMetrics(_m(quality: 33), _s(1));
      expect(s.latest?.quality, 33);
    });

    test('cancel ends without a result', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(3, _m()));
      s.cancel(_s(4));
      expect(s.result?.endReason, SessionEndReason.cancelled);
      expect(s.result?.isCancelled, isTrue);
      expect(s.result?.isSuccess, isFalse);
      expect(s.result?.duration, _s(4));
    });

    test('nothing changes after the session has ended', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(8, _m()));
      final result = s.result;
      _feed(s, List.filled(8, _m(bpm: 120)), from: 9);
      s.tick(_s(60));
      s.cancel(_s(61));
      expect(identical(s.result, result), isTrue);
    });
  });

  group('#MODE check is best-effort', () {
    const fingerLog = DeviceLog(text: 'MODE finger', kind: LogKind.mode, firmwareMode: FirmwareMode.finger);
    const wristLog = DeviceLog(text: 'MODE wrist', kind: LogKind.mode, firmwareMode: FirmwareMode.wrist);

    test('no #MODE line: no warning and the measurement works normally', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(8, _m()));
      expect(s.firmwareMismatch, isFalse);
      expect(s.result?.isSuccess, isTrue);
    });

    test('matching #MODE: no warning', () {
      final s = _session(MeasureProtocol.wrist)..onDeviceLog(wristLog);
      expect(s.firmwareMismatch, isFalse);
    });

    test('mismatching #MODE: warning, but the measurement is not blocked', () {
      final s = _session(MeasureProtocol.finger)..onDeviceLog(wristLog);
      expect(s.firmwareMismatch, isTrue);
      _feed(s, List.filled(8, _m()));
      expect(s.result?.isSuccess, isTrue);
    });

    test('other log lines do not affect the check', () {
      final s = _session(MeasureProtocol.finger)
        ..onDeviceLog(wristLog)
        ..onDeviceLog(const DeviceLog(text: 'Reset', kind: LogKind.reset));
      expect(s.firmwareMismatch, isTrue);
      s.onDeviceLog(fingerLog);
      expect(s.firmwareMismatch, isFalse);
    });
  });
}
