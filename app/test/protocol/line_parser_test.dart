import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/line_parser.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';
import 'package:repocare_band/features/band/domain/enums.dart';

void main() {
  const parser = LineParser();

  group('S lines', () {
    test('valid sample', () {
      expect(
        parser.parse('S,110190,106217,-534.4'),
        const SampleFrame(ir: 110190, red: 106217, ppg: -534.4),
      );
    });

    test('no contact sends ppg 0.0', () {
      expect(parser.parse('S,3917,4849,0.0'), const SampleFrame(ir: 3917, red: 4849, ppg: 0));
    });

    test('Windows line ending and spaces are ignored', () {
      expect(parser.parse('  S,1,2,3.5\r\n'), const SampleFrame(ir: 1, red: 2, ppg: 3.5));
    });

    test('ADC full scale is accepted, above it is rejected', () {
      expect(parser.parse('S,262143,262143,0.0'), isA<SampleFrame>());
      expect(parser.parse('S,262144,1,0.0'), isNull);
      expect(parser.parse('S,-5,1,0.0'), isNull);
    });

    test('partial and broken lines are ignored', () {
      for (final line in [
        'S',
        'S,',
        'S,110190',
        'S,110190,106217',
        'S,110190,106217,',
        'S,110190,106217,-534.4,9',
        'S,11a190,106217,-534.4',
        'S,110190,106217,NaN',
        'S,110190,106217,Infinity',
        'S;110190;106217;-534.4',
      ]) {
        expect(parser.parse(line), isNull, reason: line);
      }
    });
  });

  group('B lines', () {
    test('valid beat', () {
      expect(parser.parse('B,857'), const BeatEvent(ibiMs: 857));
    });

    test('invalid beats are ignored', () {
      for (final line in ['B', 'B,', 'B,0', 'B,-800', 'B,85.7', 'B,2001', 'B,800,1', 'Bx,800']) {
        expect(parser.parse(line), isNull, reason: line);
      }
    });
  });

  group('M lines', () {
    const full = 'M,70.3,97.5,42.1,1,88,31.2,0,0,9,1.22,0,1,6.2';

    test('full 14-field line', () {
      expect(
        parser.parse(full),
        const Metrics(
          bpm: 70.3,
          spo2: 97.5,
          rmssdMs: 42.1,
          contact: true,
          quality: 88,
          chipTempC: 31.2,
          ledMode: LedMode.auto,
          saturated: false,
          storedBeats: 9,
          perfusionIndex: 1.22,
          motion: false,
          ledCurrentMa: 6.2,
        ),
      );
    });

    test('line from the first firmware (10 fields) is still accepted', () {
      final m = parser.parse('M,65.0,-1.0,-1.0,1,50,30.0,2,0,4')! as Metrics;
      expect(m.bpm, 65.0);
      expect(m.ledMode, LedMode.level2);
      expect(m.perfusionIndex, isNull);
      expect(m.ledCurrentMa, isNull);
      expect(m.motion, isFalse);
    });

    test('cut-off or glued lines are ignored', () {
      final fields = full.split(',');
      for (var n = 1; n < fields.length; n++) {
        if (n == LineParser.metricsMinFieldCount) continue;
        final cut = fields.take(n).join(',');
        expect(parser.parse(cut), isNull, reason: cut);
      }
      expect(parser.parse('$full,99'), isNull);
      expect(parser.parse('${full}S,1,2,3'), isNull);
    });

    test('non-numeric or out-of-range fields reject the line', () {
      expect(parser.parse('M,abc,97.5,42.1,1,88,31.2,0,0,9,1.22,0,1,6.2'), isNull);
      expect(parser.parse('M,70.3,97.5,42.1,2,88,31.2,0,0,9,1.22,0,1,6.2'), isNull);
      expect(parser.parse('M,70.3,97.5,42.1,1,88,31.2,5,0,9,1.22,0,0,6.2'), isNull);
      expect(parser.parse('M,70.3,97.5,42.1,1,88,31.2,0,0,-1,1.22,0,1,6.2'), isNull);
    });
  });

  group('# lines', () {
    test('status messages are classified', () {
      expect(parser.parse('#BOOT'), const DeviceLog(text: 'BOOT', kind: LogKind.boot));
      expect(parser.parse('#OK MAX30102 ready'),
          const DeviceLog(text: 'OK MAX30102 ready', kind: LogKind.ok));
      expect((parser.parse('#ERR MAX30102 not found - check wiring')! as DeviceLog).kind,
          LogKind.error);
      expect(parser.parse('#LED auto'), const DeviceLog(text: 'LED auto', kind: LogKind.led));
      expect(parser.parse('#Reset'), const DeviceLog(text: 'Reset', kind: LogKind.reset));
      expect((parser.parse('#I2C ok, looking for sensor...')! as DeviceLog).kind, LogKind.info);
    });

    test('firmware mode', () {
      expect(
        parser.parse('#MODE finger'),
        const DeviceLog(text: 'MODE finger', kind: LogKind.mode, firmwareMode: FirmwareMode.finger),
      );
      expect((parser.parse('#MODE wrist\r')! as DeviceLog).firmwareMode, FirmwareMode.wrist);
      expect((parser.parse('#MODE banana')! as DeviceLog).firmwareMode, isNull);
    });

    test('wrist channel', () {
      expect((parser.parse('#CH IR')! as DeviceLog).channel, PpgChannel.ir);
      expect((parser.parse('#CH RED')! as DeviceLog).channel, PpgChannel.red);
      expect((parser.parse('#CH MIX')! as DeviceLog).channel, PpgChannel.mix);
    });

    test('control characters are removed, empty messages ignored', () {
      expect((parser.parse('#\u0000BOOT')! as DeviceLog).kind, LogKind.boot);
      expect(parser.parse('#'), isNull);
      expect(parser.parse('#   '), isNull);
    });
  });

  group('garbage', () {
    test('empty, unknown and binary lines return null', () {
      for (final line in [
        '',
        '   ',
        '\r',
        'Hello',
        'Something,1,2,3',
        'Mx,1',
        ',,,',
        '\u0000\u0001\u0002',
        '110190,106217,-534.4',
        '7,106217,-534.4', // a line joined mid-way after connecting
      ]) {
        expect(parser.parse(line), isNull, reason: line);
      }
    });

    test('random input never throws', () {
      final random = Random(42);
      const alphabet = 'SBM#,.-0123456789abcdefe\r\n \u0000';
      for (var i = 0; i < 20000; i++) {
        final length = random.nextInt(60);
        final line = String.fromCharCodes([
          for (var j = 0; j < length; j++) alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);
        expect(() => parser.parse(line), returnsNormally, reason: line);
      }
    });
  });
}
