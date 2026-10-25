import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';
import 'package:repocare_band/features/band/domain/enums.dart';
import 'package:repocare_band/features/band/domain/live_assessment.dart';

Metrics _m({
  double? bpm = 70,
  bool contact = true,
  int quality = 80,
  bool saturated = false,
  bool motion = false,
  double? rmssd,
}) =>
    Metrics(
      bpm: bpm,
      rmssdMs: rmssd,
      contact: contact,
      quality: quality,
      ledMode: LedMode.auto,
      saturated: saturated,
      storedBeats: 5,
      motion: motion,
    );

void main() {
  group('signal quality', () {
    test('thresholds 75 / 45', () {
      expect(signalQualityOf(_m(quality: 100)), SignalQuality.excellent);
      expect(signalQualityOf(_m(quality: 75)), SignalQuality.excellent);
      expect(signalQualityOf(_m(quality: 74)), SignalQuality.acceptable);
      expect(signalQualityOf(_m(quality: 45)), SignalQuality.acceptable);
      expect(signalQualityOf(_m(quality: 44)), SignalQuality.weak);
      expect(signalQualityOf(_m(quality: 0)), SignalQuality.weak);
    });

    test('no contact means no quality label', () {
      expect(signalQualityOf(_m(contact: false, quality: 100)), SignalQuality.none);
    });
  });

  group('hint (same order as the prototype dashboard)', () {
    test('saturated comes first, even without contact', () {
      expect(liveHintFor(_m(saturated: true, contact: false)), LiveHint.saturated);
    });

    test('no contact', () {
      expect(liveHintFor(_m(contact: false, motion: true)), LiveHint.noContact);
    });

    test('motion before settling', () {
      expect(liveHintFor(_m(motion: true, bpm: null)), LiveHint.motion);
    });

    test('settling while no heart rate yet', () {
      expect(liveHintFor(_m(bpm: null, quality: 10)), LiveHint.settling);
    });

    test('weak signal', () {
      expect(liveHintFor(_m(quality: 44)), LiveHint.weakSignal);
    });

    test('stable', () {
      expect(liveHintFor(_m(quality: 45)), LiveHint.stable);
    });

    test('warnings', () {
      expect(LiveHint.values.where((h) => h.isWarning).toSet(),
          {LiveHint.saturated, LiveHint.motion, LiveHint.weakSignal});
    });
  });

  group('held heart rate (firmware v2.2)', () {
    test('a BPM with quality below 40 is the held last reading', () {
      expect(isHeldHeartRate(_m(bpm: 72, quality: 39)), isTrue);
      expect(isHeldHeartRate(_m(bpm: 72, quality: 0)), isTrue);
      expect(isHeldHeartRate(_m(bpm: 72, quality: 0, contact: false)), isTrue,
          reason: 'the rule is only bpm > 0 and quality < 40');
    });

    test('quality 40 or more is a live reading', () {
      expect(isHeldHeartRate(_m(bpm: 72, quality: 40)), isFalse);
      expect(isHeldHeartRate(_m(bpm: 72, quality: 90)), isFalse);
    });

    test('no BPM is never held', () {
      expect(isHeldHeartRate(_m(bpm: null, quality: 10)), isFalse);
    });
  });

  group('HRV waiting state', () {
    test('waiting while there is contact but no RMSSD', () {
      expect(isWaitingForHrv(_m()), isTrue);
      expect(isWaitingForHrv(_m(rmssd: 52)), isFalse);
      expect(isWaitingForHrv(_m(contact: false)), isFalse, reason: 'no contact shows --');
    });

    test('steady seconds count readings with quality >= 45 and restart below', () {
      var seconds = 0;
      for (var i = 0; i < 30; i++) {
        seconds = nextHrvSteadySeconds(seconds, _m(quality: 45));
      }
      expect(seconds, 30);
      seconds = nextHrvSteadySeconds(seconds, _m(quality: 44));
      expect(seconds, 0, reason: 'one weak second restarts the count');
      seconds = nextHrvSteadySeconds(seconds, _m(quality: 90));
      expect(seconds, 1);
      expect(nextHrvSteadySeconds(12, _m(contact: false, quality: 0)), 0);
    });

    test('the count keeps going past 60 s; the tile caps what it shows', () {
      expect(nextHrvSteadySeconds(60, _m()), 61);
    });
  });
}
