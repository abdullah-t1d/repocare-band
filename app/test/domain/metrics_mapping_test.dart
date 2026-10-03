import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/line_parser.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';
import 'package:repocare_band/features/band/domain/enums.dart';

/// "Not available" values must become `null` so the UI can never show them.
void main() {
  const parser = LineParser();

  Metrics parse(String line) => parser.parse(line)! as Metrics;

  test('firmware "not available" values (-1.0, -99, -1.00, 0.0 mA) map to null', () {
    // Exactly what Serial.print(-1, 1) etc. produce in the sketches.
    final m = parse('M,-1.0,-1.0,-1.0,0,0,-99,0,0,0,-1.00,0,1,0.0');
    expect(m.bpm, isNull);
    expect(m.spo2, isNull);
    expect(m.rmssdMs, isNull);
    expect(m.chipTempC, isNull);
    expect(m.perfusionIndex, isNull);
    expect(m.ledCurrentMa, isNull);
    expect(m.contact, isFalse);
    expect(m.quality, 0);
  });

  test('-1 without decimals is also "not available"', () {
    final m = parse('M,-1,-1,-1,1,10,-99,0,0,0,-1,0,1,6.2');
    expect(m.bpm, isNull);
    expect(m.spo2, isNull);
    expect(m.rmssdMs, isNull);
    expect(m.perfusionIndex, isNull);
  });

  test('a real chip temperature below zero is kept, the -99 sentinel is not', () {
    expect(parse('M,70.0,-1.0,-1.0,1,80,-5.5,0,0,0,1.00,0,1,6.2').chipTempC, -5.5);
    expect(parse('M,70.0,-1.0,-1.0,1,80,-99.0,0,0,0,1.00,0,1,6.2').chipTempC, isNull);
  });

  test('RMSSD and PI of exactly 0 are real values', () {
    final m = parse('M,70.0,-1.0,0.0,1,80,30.0,0,0,3,0.00,0,1,6.2');
    expect(m.rmssdMs, 0);
    expect(m.perfusionIndex, 0);
  });

  test('LED mode: auto flag wins, otherwise the fixed level', () {
    expect(parse('M,70,-1,-1,1,80,30,0,0,0,1,0,1,6.2').ledMode, LedMode.auto);
    expect(parse('M,70,-1,-1,1,80,30,3,0,0,1,0,0,25.0').ledMode, LedMode.level3);
    expect(parse('M,70,-1,-1,1,80,30,4,0,0,1,0,1,50.0').ledMode, LedMode.auto);
    expect(parse('M,70,-1,-1,1,80,30,0,0,0,1,0,0,6.2').ledMode, LedMode.auto);
  });

  test('flags', () {
    final m = parse('M,70,-1,-1,1,80,30,0,1,12,1,1,1,6.2');
    expect(m.saturated, isTrue);
    expect(m.motion, isTrue);
    expect(m.storedBeats, 12);
  });

  test('quality is clamped to 0–100', () {
    expect(parse('M,70,-1,-1,1,140,30,0,0,0,1,0,1,6.2').quality, 100);
    expect(parse('M,70,-1,-1,1,-3,30,0,0,0,1,0,1,6.2').quality, 0);
  });
}
