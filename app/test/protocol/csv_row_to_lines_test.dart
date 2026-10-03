import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/core/constants/band_constants.dart';
import 'package:repocare_band/features/band/data/protocol/csv_row_to_lines.dart';
import 'package:repocare_band/features/band/data/protocol/line_parser.dart';
import 'package:repocare_band/features/band/data/recording/csv_recorder.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';

const _recordings = [
  'finger_rest_80s.csv',
  'wrist_back_rest_221s.csv',
  'wrist_inner_no_pulse_134s.csv',
];

String _readRecording(String name) => File('assets/recordings/$name').readAsStringSync();

void main() {
  const parser = LineParser();

  group('RecordingRow', () {
    test('parses a data row', () {
      final r = RecordingRow.tryParse(
          '1790869504809,110190,106217,-534.4,1,70.3,-1,47,auto,1,1.22,0,6.2\r')!;
      expect(r.timeMs, 1790869504809);
      expect(r.ir, 110190);
      expect(r.ppg, -534.4);
      expect(r.beat, isTrue);
      expect(r.bpm, 70.3);
      expect(r.quality, 47);
      expect(r.led, 'auto');
      expect(r.contact, isTrue);
      expect(r.ledMa, 6.2);
    });

    test('header, short and invalid rows are skipped', () {
      expect(RecordingRow.tryParse(CsvRecorder.header), isNull);
      expect(RecordingRow.tryParse('1,2,3'), isNull);
      expect(RecordingRow.tryParse('1,2,3,4,0,70,-1,47,bright,1,1,0,6'), isNull);
      expect(parseRecording('${CsvRecorder.header}\n\n1,2\n'), isEmpty);
    });
  });

  group('RecordingToLines', () {
    RecordingRow row({
      int timeMs = 0,
      int ir = 100000,
      bool beat = false,
      double bpm = 70,
      int quality = 80,
      String led = 'auto',
      bool contact = true,
    }) =>
        RecordingRow(
          timeMs: timeMs,
          ir: ir,
          red: 90000,
          ppg: -12.5,
          beat: beat,
          bpm: bpm,
          spo2: -1,
          quality: quality,
          led: led,
          contact: contact,
          pi: 1.2,
          motion: false,
          ledMa: 6.2,
        );

    test('first row: M, then S; missing fields are sent as "not available"', () {
      final lines = RecordingToLines().linesFor(row());
      expect(lines, [
        'M,70.0,-1.0,-1.0,1,80,-99,0,0,0,1.20,0,1,6.2',
        'S,100000,90000,-12.5',
      ]);
      final m = parser.parse(lines.first)! as Metrics;
      expect(m.rmssdMs, isNull);
      expect(m.chipTempC, isNull);
    });

    test('M only when the metric columns change, and at least once per 100 rows', () {
      final c = RecordingToLines();
      var mCount = 0;
      for (var i = 0; i < 250; i++) {
        mCount += c.linesFor(row(timeMs: i * 10)).where((l) => l.startsWith('M')).length;
      }
      expect(mCount, 3); // rows 0, 100, 200
      expect(c.linesFor(row(quality: 81)).first, startsWith('M,'));
    });

    test('beat: B before S, interval from the timestamps', () {
      final c = RecordingToLines()..linesFor(row(beat: true));
      final lines = c.linesFor(row(timeMs: 850, beat: true));
      expect(lines, ['B,850', 'S,100000,90000,-12.5']);
    });

    test('beat interval outside 300–2000 ms is estimated from BPM', () {
      final c = RecordingToLines();
      expect(c.linesFor(row(beat: true, bpm: 60)), contains('B,1000'));
      expect(c.linesFor(row(timeMs: 5000, beat: true, bpm: 75)), contains('B,800'));
    });

    test('fixed LED level and saturation', () {
      final lines = RecordingToLines().linesFor(row(led: '3', ir: BandConstants.saturationIr + 1));
      final m = parser.parse(lines.first)! as Metrics;
      expect(m.ledMode.level, 3);
      expect(m.saturated, isTrue);
    });

    test('stored beats count since contact, capped at 12, reset without contact', () {
      final c = RecordingToLines();
      Metrics metricsAfter(RecordingRow r) =>
          parser.parse(c.linesFor(r).firstWhere((l) => l.startsWith('M')))! as Metrics;

      for (var i = 0; i < 14; i++) {
        c.linesFor(row(timeMs: i * 800, beat: true));
      }
      expect(metricsAfter(row(timeMs: 20000, quality: 99)).storedBeats, 12);
      expect(metricsAfter(row(timeMs: 20010, contact: false)).storedBeats, 0);
    });

    test('every generated line is valid protocol', () {
      for (final name in _recordings) {
        final c = RecordingToLines();
        for (final r in parseRecording(_readRecording(name))) {
          for (final line in c.linesFor(r)) {
            expect(parser.parse(line), isNotNull, reason: '$name: $line');
          }
        }
      }
    });
  });

  group('round trip with the real recordings', () {
    // recording -> protocol lines -> parser -> recorder -> CSV
    // must reproduce every column except the computer time.
    for (final name in _recordings) {
      test(name, () {
        final original = _readRecording(name)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        final rows = parseRecording(original.join('\n'));
        expect(rows, hasLength(original.length - 1), reason: 'no row may be dropped');

        final converter = RecordingToLines();
        final recorder = CsvRecorder()..start();
        for (final r in rows) {
          for (final line in converter.linesFor(r)) {
            recorder.onEvent(parser.parse(line)!);
          }
        }
        recorder.stop();

        final replayed = recorder.toCsv().split('\n');
        expect(replayed.first, original.first);
        expect(replayed, hasLength(original.length));
        for (var i = 1; i < original.length; i++) {
          final a = original[i].split(',').sublist(1).join(',');
          final b = replayed[i].split(',').sublist(1).join(',');
          if (a != b) fail('$name row $i differs:\n  original $a\n  replayed $b');
        }
      });
    }
  });
}
