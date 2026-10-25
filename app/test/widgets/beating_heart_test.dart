import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/presentation/widgets/beating_heart.dart';

Widget _heart(int beats, {double? bpm = 60, bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: BeatingHeart(beatCount: beats, bpm: bpm, color: Colors.red)),
      ),
    );

double _scale(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(BeatingHeart.iconKey)).transform.getMaxScaleOnAxis();

void main() {
  testWidgets('pulses on a new beat, not on a timer', (tester) async {
    await tester.pumpWidget(_heart(0));
    await tester.pump(const Duration(seconds: 3));
    expect(_scale(tester), 1.0, reason: 'no beat, no pulse');

    await tester.pumpWidget(_heart(1));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scale(tester), greaterThan(1.05));

    await tester.pump(const Duration(seconds: 1));
    expect(_scale(tester), 1.0, reason: 'back to rest after the pulse');
  });

  testWidgets('a rebuild without a new beat does not pulse', (tester) async {
    await tester.pumpWidget(_heart(5));
    await tester.pumpWidget(_heart(5, bpm: 90));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scale(tester), 1.0);
  });

  testWidgets('reduce motion: no pulsing', (tester) async {
    await tester.pumpWidget(_heart(0, reduceMotion: true));
    await tester.pumpWidget(_heart(1, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scale(tester), 1.0);
  });

  test('pulse speed follows the heart rate', () {
    expect(BeatingHeart.pulseDuration(60), const Duration(milliseconds: 450));
    expect(BeatingHeart.pulseDuration(120), const Duration(milliseconds: 225));
    expect(BeatingHeart.pulseDuration(200), const Duration(milliseconds: 180), reason: 'lower bound');
    expect(BeatingHeart.pulseDuration(30), const Duration(milliseconds: 520), reason: 'upper bound');
    expect(BeatingHeart.pulseDuration(null), const Duration(milliseconds: 420));
    expect(BeatingHeart.pulseDuration(120) < BeatingHeart.pulseDuration(60), isTrue);
  });
}
