/// Resting heart-rate zone, used to colour the UI and to word the result.
///
/// The zones describe a reading **at rest** and are deliberately
/// non-diagnostic: they say "higher than usual at rest", never "danger".
///
/// | Zone       | BPM (rounded) |
/// |------------|---------------|
/// | [low]      | below 50      |
/// | [normal]   | 50 – 100      |
/// | [elevated] | 101 – 120     |
/// | [high]     | above 120     |
enum HeartRateZone {
  low,
  normal,
  elevated,
  high;

  /// Zone for [bpm]. The value is rounded first, because the UI shows whole
  /// numbers and the zone must match the number on screen.
  static HeartRateZone forBpm(double bpm) {
    final rounded = bpm.round();
    if (rounded < 50) return HeartRateZone.low;
    if (rounded <= 100) return HeartRateZone.normal;
    if (rounded <= 120) return HeartRateZone.elevated;
    return HeartRateZone.high;
  }
}
