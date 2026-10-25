import 'package:flutter/foundation.dart';

import '../../../../core/constants/band_constants.dart';
import '../../../../core/utils/ring_buffer.dart';
import '../../domain/band_event.dart';

/// Latest raw ADC values, for the raw-data panel.
typedef RawSample = ({int ir, int red});

/// The last 6 s of the pulse wave plus the beat positions.
///
/// Samples arrive 100 times per second. They are kept out of the Riverpod
/// state so the page does not rebuild for each one: the waveform painter
/// listens to this object and only repaints.
class WaveformBuffer extends ChangeNotifier {
  WaveformBuffer({int capacity = BandConstants.waveformSamples})
      : _samples = DoubleRingBuffer(capacity);

  /// Beat marks older than the window are dropped; this is a safe upper bound.
  static const int _maxBeatMarks = 40;

  /// The raw panel is refreshed every 20 samples (5 times per second).
  static const int _rawEvery = 20;

  final DoubleRingBuffer _samples;
  final List<int> _beatMarks = [];
  int _sampleNo = 0;

  /// Raw IR / RED, updated 5 times per second.
  final ValueNotifier<RawSample?> raw = ValueNotifier<RawSample?>(null);

  int get capacity => _samples.capacity;

  int get length => _samples.length;

  bool get isEmpty => _samples.isEmpty;

  /// Total samples received since the last [clear].
  int get sampleCount => _sampleNo;

  /// Sample at [index], 0 = oldest.
  double operator [](int index) => _samples[index];

  /// How many samples ago each visible beat happened (0 = newest sample).
  Iterable<int> get beatAges sync* {
    for (final mark in _beatMarks) {
      final age = _sampleNo - mark;
      if (age >= 0 && age < capacity) yield age;
    }
  }

  void addSample(SampleFrame sample) {
    _samples.add(sample.ppg);
    _sampleNo++;
    if (_sampleNo % _rawEvery == 1) raw.value = (ir: sample.ir, red: sample.red);
    notifyListeners();
  }

  /// The firmware reports a beat ~150 ms after its upstroke; the mark is
  /// moved back so the tick sits on the upstroke.
  void markBeat() {
    _beatMarks.add(_sampleNo - BandConstants.beatMarkerDelaySamples);
    if (_beatMarks.length > _maxBeatMarks) _beatMarks.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _samples.clear();
    _beatMarks.clear();
    _sampleNo = 0;
    raw.value = null;
    notifyListeners();
  }

  @override
  void dispose() {
    raw.dispose();
    super.dispose();
  }
}
