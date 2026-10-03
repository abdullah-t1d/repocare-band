import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/core/utils/ring_buffer.dart';
import 'package:repocare_band/core/utils/stats.dart';

void main() {
  group('median', () {
    test('odd, even, empty', () {
      expect(median([3, 1, 2]), 2);
      expect(median([4, 1, 3, 2]), 2.5);
      expect(median(<double>[]), isNull);
      expect(median([7]), 7);
    });

    test('does not modify the input', () {
      final input = [3.0, 1.0, 2.0];
      median(input);
      expect(input, [3.0, 1.0, 2.0]);
    });
  });

  group('DoubleRingBuffer', () {
    test('keeps the newest values in order', () {
      final b = DoubleRingBuffer(3);
      expect(b.isEmpty, isTrue);
      b
        ..add(1)
        ..add(2);
      expect(b.toList(), [1, 2]);
      b
        ..add(3)
        ..add(4)
        ..add(5);
      expect(b.length, 3);
      expect(b.toList(), [3, 4, 5]);
      expect(b[0], 3);
      expect(b[2], 5);
      expect(() => b[3], throwsRangeError);
    });

    test('clear', () {
      final b = DoubleRingBuffer(2)
        ..add(1)
        ..clear();
      expect(b.length, 0);
      b.add(9);
      expect(b.toList(), [9]);
    });
  });
}
