import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The demo recordings in `app/assets/recordings/` are copies of the validated
/// files in `1_heart_rate/test_data/` (Flutter can only bundle files inside the
/// app folder). This test fails if a copy ever drifts from its original.
void main() {
  const names = [
    'finger_rest_80s.csv',
    'wrist_back_rest_221s.csv',
    'wrist_inner_no_pulse_134s.csv',
  ];

  for (final name in names) {
    test('$name is byte-identical to 1_heart_rate/test_data', () {
      final original = File('../1_heart_rate/test_data/$name');
      final copy = File('assets/recordings/$name');
      expect(original.existsSync(), isTrue, reason: original.path);
      expect(copy.existsSync(), isTrue, reason: copy.path);
      expect(copy.readAsBytesSync(), original.readAsBytesSync());
    });
  }

  test('every recording in test_data has a copy', () {
    final originals = Directory('../1_heart_rate/test_data')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.csv'))
        .toSet();
    expect(originals, names.toSet());
  });
}
