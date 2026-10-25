import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/domain/heart_rate_zone.dart';

void main() {
  test('zone boundaries', () {
    final expected = {
      30.0: HeartRateZone.low,
      49.0: HeartRateZone.low,
      50.0: HeartRateZone.normal,
      72.0: HeartRateZone.normal,
      100.0: HeartRateZone.normal,
      101.0: HeartRateZone.elevated,
      120.0: HeartRateZone.elevated,
      121.0: HeartRateZone.high,
      180.0: HeartRateZone.high,
    };
    expected.forEach((bpm, zone) => expect(HeartRateZone.forBpm(bpm), zone, reason: '$bpm'));
  });

  test('the zone matches the rounded number shown on screen', () {
    expect(HeartRateZone.forBpm(49.4), HeartRateZone.low); // shows 49
    expect(HeartRateZone.forBpm(49.5), HeartRateZone.normal); // shows 50
    expect(HeartRateZone.forBpm(100.4), HeartRateZone.normal); // shows 100
    expect(HeartRateZone.forBpm(100.5), HeartRateZone.elevated); // shows 101
    expect(HeartRateZone.forBpm(120.4), HeartRateZone.elevated);
    expect(HeartRateZone.forBpm(120.5), HeartRateZone.high);
  });
}
