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
    test('finger: up to 75 s, ends on HRV, no stable early stop', () {
      const p = MeasureProtocol.finger;
      expect(p.maxDuration, const Duration(seconds: 75));
      expect(p.endsOnHrv, isTrue);
      expect(p.stableQuality, isNull);
      expect(p.stableWindow, isNull);
      expect(p.reportsSpo2, isTrue);
    });

    test('wrist: unchanged, 60 s, quality 60 for 10 s, no SpO2', () {
      const p = MeasureProtocol.wrist;
      expect(p.maxDuration, const Duration(seconds: 60));
      expect(p.endsOnHrv, isFalse);
      expect(p.stableQuality, 60);
      expect(p.stableWindow, const Duration(seconds: 10));
      expect(p.reportsSpo2, isFalse);
    });
  });

  group('finger: waits for HRV', () {
    test('a stable heart rate alone does not end it; HR and SpO2 are available early', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(40, _m(quality: 95, spo2: 97)));
      expect(s.isFinished, isFalse, reason: 'v2.2: keep going until HRV arrives');
      expect(s.latest?.bpm, 70);
      expect(s.latest?.spo2, 97);
      expect(s.stableProgress, 0, reason: 'no early stop on the finger');
    });

    test('ends when the first valid HRV arrives', () {
      final s = _session(MeasureProtocol.finger);
      final bpms = <double>[90, 72, 71, 70, 69, 70, 71, 72, 70, 71];
      _feed(s, [
        for (final b in bpms) _m(bpm: b, quality: 60, spo2: 97),
        for (var i = 0; i < 40; i++) _m(quality: 80, spo2: 98),
      ]);
      expect(s.isFinished, isFalse);

      s.addMetrics(_m(bpm: 71, quality: 82, spo2: 98, rmssd: 48.5), _s(51));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.hrvReceived);
      expect(r.isSuccess, isTrue);
      expect(r.hrvMs, 48.5, reason: 'the firmware value as received, not a median');
      expect(r.hrvUnavailable, isFalse);
      expect(r.bpm, 70, reason: 'median of all good readings');
      expect(r.spo2, 98);
      expect(r.readingsUsed, 51);
      expect(r.duration, _s(51));
    });

    test('HRV without skin contact does not end it', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(10, _m()));
      s.addMetrics(_m(contact: false, rmssd: 50), _s(11));
      expect(s.isFinished, isFalse);
    });

    test('timeout at 75 s without HRV: HR and SpO2, HRV marked unavailable', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(74, _m(bpm: 66, quality: 70, spo2: 96)));
      expect(s.isFinished, isFalse);
      s.tick(_s(75));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.timeout);
      expect(r.isSuccess, isTrue);
      expect(r.bpm, 66);
      expect(r.spo2, 96);
      expect(r.hrvMs, isNull);
      expect(r.hrvUnavailable, isTrue, reason: 'card shows "needs a full minute of stillness"');
      expect(r.duration, _s(75));
    });

    test('timeout with too few good readings: no heart rate either', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, [...List.filled(4, _m(quality: 50)), ...List.filled(60, _m(quality: 20))]);
      s.tick(_s(75));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.timeout);
      expect(r.isSuccess, isFalse);
      expect(r.bpm, isNull);
      expect(r.spo2, isNull);
      expect(r.hrvUnavailable, isTrue);
    });

    test('HRV may arrive while the heart-rate signal is still weak', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(20, _m(quality: 30)));
      s.addMetrics(_m(quality: 30, rmssd: 40), _s(21));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.hrvReceived);
      expect(r.hrvMs, 40);
      expect(r.isSuccess, isFalse, reason: 'no reliable heart rate');
    });
  });

  group('wrist: early stop', () {
    test('stops after 10 s of quality >= 60 with the median of that part', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, [_m(bpm: 90, quality: 40), _m(bpm: 88, quality: 50)]); // settling
      final bpms = <double>[70, 72, 71, 69, 73, 70, 71, 72, 70, 71];
      _feed(s, [for (final b in bpms) _m(bpm: b, quality: 65, rmssd: 40, spo2: 97)], from: 3);

      expect(s.isFinished, isTrue);
      final r = s.result!;
      expect(r.endReason, SessionEndReason.stable);
      expect(r.isSuccess, isTrue);
      expect(r.bpm, 71); // median of the stable part only, not of 90/88
      expect(r.hrvMs, 40);
      expect(r.hrvUnavailable, isFalse, reason: 'the wrist does not wait for HRV');
      expect(r.spo2, isNull, reason: 'SpO2 is finger only');
      expect(r.quality, 65);
      expect(r.readingsUsed, 10);
      expect(r.duration, _s(12));
      expect(r.startedAt, _start);
    });

    test('9 stable seconds are not enough', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(9, _m(quality: 60)));
      expect(s.isFinished, isFalse);
      expect(s.stableFor, _s(9));
      expect(s.stableProgress, closeTo(9 / 10, 1e-9));
    });

    test('a weak reading restarts the stable part', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, [
        ...List.filled(6, _m(quality: 80)),
        _m(quality: 59),
        ...List.filled(9, _m(quality: 80)),
      ]);
      expect(s.isFinished, isFalse);
      s.addMetrics(_m(quality: 80), _s(17));
      expect(s.result?.endReason, SessionEndReason.stable);
      expect(s.result?.readingsUsed, 10);
    });

    test('motion, saturation, lost contact or missing BPM break the stable part', () {
      for (final bad in [
        _m(motion: true),
        _m(saturated: true),
        _m(contact: false),
        _m(bpm: null),
      ]) {
        final s = _session(MeasureProtocol.wrist);
        _feed(s, [...List.filled(9, _m()), bad]);
        expect(s.stableFor, Duration.zero, reason: '$bad');
        expect(s.isFinished, isFalse);
      }
    });

    test('a gap of more than 2.5 s between readings restarts the stable part', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(5, _m()));
      _feed(s, List.filled(3, _m()), from: 9); // 4 s silence after t=5
      expect(s.isFinished, isFalse);
      expect(s.stableFor, _s(3));
    });

    test('an HRV value does not end the wrist measurement', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(5, _m(quality: 50, rmssd: 45)));
      expect(s.isFinished, isFalse);
    });
  });

  group('wrist: timeout', () {
    test('with at least 5 good readings: median of the good readings', () {
      final s = _session(MeasureProtocol.wrist);
      // Quality 50 is "good" (>= 45) but never "stable" (>= 60).
      _feed(s, [
        _m(bpm: 60, quality: 50),
        _m(bpm: 62, quality: 50),
        _m(bpm: 64, quality: 50),
        _m(bpm: 66, quality: 50),
        _m(bpm: 68, quality: 50),
        _m(bpm: 150, quality: 30), // weak, ignored
        _m(bpm: 140, contact: false), // no contact, ignored
      ]);
      s.tick(_s(59.9));
      expect(s.isFinished, isFalse);
      s.tick(_s(60));
      final r = s.result!;
      expect(r.endReason, SessionEndReason.timeout);
      expect(r.isSuccess, isTrue);
      expect(r.bpm, 64);
      expect(r.readingsUsed, 5);
      expect(r.quality, 50);
      expect(r.hrvMs, isNull);
      expect(r.duration, _s(60));
    });

    test('no readings at all (e.g. inner wrist): no reliable reading after 60 s', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(59, _m(bpm: null, quality: 0)));
      expect(s.isFinished, isFalse);
      s.tick(_s(60));
      expect(s.result?.isSuccess, isFalse);
    });

    test('a reading that arrives after the time is up also ends the session', () {
      final s = _session(MeasureProtocol.wrist);
      s.addMetrics(_m(quality: 10), _s(61));
      expect(s.result?.endReason, SessionEndReason.timeout);
    });
  });

  group('session state', () {
    test('progress and remaining time', () {
      final s = _session(MeasureProtocol.finger);
      expect(s.progress, 0);
      expect(s.remaining, _s(75));
      s.tick(_s(30));
      expect(s.progress, 0.4);
      expect(s.remaining, _s(45));
      s.tick(_s(10)); // time never goes back
      expect(s.elapsed, _s(30));
      s.tick(_s(90));
      expect(s.progress, 1);
      expect(s.remaining, Duration.zero);
    });

    test('latest reading is exposed for the live quality display', () {
      final s = _session(MeasureProtocol.finger);
      expect(s.latest, isNull);
      s.addMetrics(_m(quality: 33), _s(1));
      expect(s.latest?.quality, 33);
    });

    test('cancel ends without a result and without the HRV message', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, List.filled(3, _m()));
      s.cancel(_s(4));
      expect(s.result?.endReason, SessionEndReason.cancelled);
      expect(s.result?.isCancelled, isTrue);
      expect(s.result?.isSuccess, isFalse);
      expect(s.result?.hrvUnavailable, isFalse);
      expect(s.result?.duration, _s(4));
    });

    test('nothing changes after the session has ended', () {
      final s = _session(MeasureProtocol.finger);
      _feed(s, [...List.filled(8, _m()), _m(rmssd: 50)]);
      final result = s.result;
      expect(result?.endReason, SessionEndReason.hrvReceived);
      _feed(s, List.filled(8, _m(bpm: 120, rmssd: 90)), from: 10);
      s.tick(_s(80));
      s.cancel(_s(81));
      expect(identical(s.result, result), isTrue);
    });
  });

  group('#MODE check is best-effort', () {
    const fingerLog = DeviceLog(text: 'MODE finger', kind: LogKind.mode, firmwareMode: FirmwareMode.finger);
    const wristLog = DeviceLog(text: 'MODE wrist', kind: LogKind.mode, firmwareMode: FirmwareMode.wrist);

    test('no #MODE line: no warning and the measurement works normally', () {
      final s = _session(MeasureProtocol.wrist);
      _feed(s, List.filled(10, _m()));
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
      _feed(s, [...List.filled(8, _m()), _m(rmssd: 42)]);
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
