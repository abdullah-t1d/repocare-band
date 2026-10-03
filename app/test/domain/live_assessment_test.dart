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
}) =>
    Metrics(
      bpm: bpm,
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
}
