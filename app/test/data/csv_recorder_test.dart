import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/line_parser.dart';
import 'package:repocare_band/features/band/data/recording/csv_recorder.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';

void main() {
  const parser = LineParser();
  final t0 = DateTime.utc(2026, 10, 3, 9, 5, 7);

  /// Clock that moves 10 ms per call, like samples at 100/s.
  CsvRecorder recorderWithClock() {
    var calls = 0;
    return CsvRecorder(now: () => t0.add(Duration(milliseconds: 10 * calls++)));
  }

  void feed(CsvRecorder r, List<String> lines) {
    for (final l in lines) {
      final e = parser.parse(l);
      if (e != null) r.onEvent(e);
    }
  }

  test('header matches the prototype dashboard and the test_data files', () {
    expect(CsvRecorder.header,
        'time_ms,ir,red,ppg,beat,bpm,spo2,quality,led,contact,pi,motion,led_mA');
  });

  test('nothing is recorded before start', () {
    final r = recorderWithClock();
    feed(r, ['S,1,2,3.0', 'S,1,2,3.0']);
    expect(r.rowCount, 0);
    expect(r.canExport, isFalse);
  });

  test('one row per sample, metrics from the last M line, beat on the next sample', () {
    final r = recorderWithClock();
    feed(r, ['M,70.3,97.5,42.1,1,88,31.2,0,0,9,1.22,0,1,6.2']); // before start
    r.start();
    feed(r, [
      'S,110190,106217,-534.4',
      'B,857',
      'S,110147,106206,-539.0',
      'S,110032,106140,0.0',
      'M,-1.0,-1.0,-1.0,0,0,-99,2,0,0,-1.00,0,0,12.4',
      'S,3917,4849,0.0',
      '#OK MAX30102 ready',
      'garbage line',
    ]);
    r.stop();

    final lines = r.toCsv().split('\n');
    expect(lines.first, CsvRecorder.header);
    final t = t0.millisecondsSinceEpoch;
    expect(lines.sublist(1), [
      '$t,110190,106217,-534.4,0,70.3,97.5,88,auto,1,1.22,0,6.2',
      '${t + 10},110147,106206,-539.0,1,70.3,97.5,88,auto,1,1.22,0,6.2',
      '${t + 20},110032,106140,0.0,0,70.3,97.5,88,auto,1,1.22,0,6.2',
      '${t + 30},3917,4849,0.0,0,-1,-1,0,2,0,-1,0,12.4',
    ]);
    expect(r.canExport, isTrue);
    expect(r.toCsv().endsWith('\n'), isFalse);
  });

  test('before any M line the defaults of the prototype are written', () {
    final r = recorderWithClock()..start();
    feed(r, ['S,5,6,0.0']);
    expect(r.toCsv().split('\n')[1].split(',').sublist(1),
        ['5', '6', '0.0', '0', '-1', '-1', '0', 'auto', '0', '-1', '0', '0']);
  });

  test('a beat seen while not recording is not carried into the next recording', () {
    final r = recorderWithClock();
    feed(r, ['B,800', 'S,1,1,0.0']);
    r.start();
    feed(r, ['S,1,1,0.0']);
    expect(r.toCsv().split('\n')[1].split(',')[4], '0');
  });

  test('start discards the previous recording; export only when stopped', () {
    final r = recorderWithClock()..start();
    feed(r, ['S,1,1,0.0', 'S,1,1,0.0']);
    expect(r.canExport, isFalse, reason: 'still recording');
    r.stop();
    expect(r.rowCount, 2);
    r.start();
    expect(r.rowCount, 0);
  });

  test('file name: repocare_<led>_<UTC time>.csv', () {
    final r = CsvRecorder(now: () => DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(r.fileName(), 'repocare_auto_2026-01-02-03-04-05.csv');
    r.onEvent(parser.parse('M,70,-1,-1,1,80,30,3,0,0,1,0,0,25.0')! as Metrics);
    expect(r.fileName(), 'repocare_3_2026-01-02-03-04-05.csv');
  });

  test('numbers are written like JavaScript', () {
    expect(formatCsvNumber(-1), '-1');
    expect(formatCsvNumber(70.3), '70.3');
    expect(formatCsvNumber(6.2), '6.2');
    expect(formatCsvNumber(0), '0');
    expect(formatCsvNumber(100), '100');
  });
}
