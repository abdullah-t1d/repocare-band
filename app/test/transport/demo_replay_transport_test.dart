import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/line_parser.dart';
import 'package:repocare_band/features/band/data/transport/band_transport.dart';
import 'package:repocare_band/features/band/data/transport/demo_recording.dart';
import 'package:repocare_band/features/band/data/transport/demo_replay_transport.dart';
import 'package:repocare_band/features/band/domain/band_event.dart';
import 'package:repocare_band/features/band/domain/enums.dart';

/// 3 s of a synthetic finger recording: 300 rows, a beat every 80 rows.
String _csv({int rows = 300}) {
  final b = StringBuffer('time_ms,ir,red,ppg,beat,bpm,spo2,quality,led,contact,pi,motion,led_mA\n');
  for (var i = 0; i < rows; i++) {
    final beat = i % 80 == 79 ? 1 : 0;
    b.writeln('${1000 + i * 10},${100000 + i},${90000 + i},${(i % 50) - 25}.0,$beat,'
        '75.0,98.0,90,auto,1,1.10,0,6.2');
  }
  return b.toString();
}

class _Harness {
  _Harness(String csv)
      : transport = DemoReplayTransport(
          recording: DemoRecording.fingerRest,
          loadAsset: (_) async => csv,
        ) {
    transport.lines.listen(lines.add);
  }

  final DemoReplayTransport transport;
  final List<String> lines = [];

  int get samples => lines.where((l) => l.startsWith('S,')).length;
}

void main() {
  test('replays at 100 rows per second and announces the sketch', () {
    fakeAsync((async) {
      final h = _Harness(_csv());
      unawaited(h.transport.connect());
      async.flushMicrotasks();
      expect(h.transport.state, BandConnectionState.connected);
      expect(h.transport.playback.length, const Duration(seconds: 3));

      async.elapse(const Duration(seconds: 1));
      expect(h.samples, 100);
      expect(h.lines.first, '#MODE finger');
      expect(h.lines.where((l) => l.startsWith('M,')), isNotEmpty);
      expect(h.lines.where((l) => l.startsWith('B,')), hasLength(1));
      expect(h.transport.playback.position, const Duration(seconds: 1));

      unawaited(h.transport.dispose());
      async.flushMicrotasks();
    });
  });

  test('every emitted line is valid protocol', () {
    fakeAsync((async) {
      final h = _Harness(_csv());
      unawaited(h.transport.connect());
      async.elapse(const Duration(seconds: 2));
      const parser = LineParser();
      for (final line in h.lines) {
        expect(parser.parse(line), isNotNull, reason: line);
      }
      final m = h.lines.map(parser.parse).whereType<Metrics>().first;
      expect(m.bpm, 75.0);
      expect(m.rmssdMs, isNull, reason: 'not in the recording, sent as not available');
      unawaited(h.transport.dispose());
      async.flushMicrotasks();
    });
  });

  group('controls', () {
    test('pause stops the stream, resume continues', () {
      fakeAsync((async) {
        final h = _Harness(_csv());
        unawaited(h.transport.connect());
        async.elapse(const Duration(milliseconds: 500));
        h.transport.pause();
        expect(h.transport.playback.paused, isTrue);
        final before = h.samples;
        async.elapse(const Duration(seconds: 2));
        expect(h.samples, before);

        h.transport.resume();
        async.elapse(const Duration(milliseconds: 500));
        expect(h.samples, before + 50);
        unawaited(h.transport.dispose());
        async.flushMicrotasks();
      });
    });

    test('2x speed doubles the rate', () {
      fakeAsync((async) {
        final h = _Harness(_csv(rows: 1000));
        unawaited(h.transport.connect());
        async.flushMicrotasks();
        h.transport.setSpeed(2);
        async.elapse(const Duration(seconds: 1));
        expect(h.samples, 200);
        expect(h.transport.playback.speed, 2);
        expect(() => h.transport.setSpeed(3), throwsArgumentError);
        unawaited(h.transport.dispose());
        async.flushMicrotasks();
      });
    });

    test('restart goes back to the first row', () {
      fakeAsync((async) {
        final h = _Harness(_csv());
        unawaited(h.transport.connect());
        async.elapse(const Duration(milliseconds: 1500));
        h.transport.restart();
        expect(h.transport.playback.position, Duration.zero);
        h.lines.clear();
        async.elapse(const Duration(milliseconds: 20));
        expect(h.lines.firstWhere((l) => l.startsWith('S,')), startsWith('S,100000,90000,'));
        unawaited(h.transport.dispose());
        async.flushMicrotasks();
      });
    });

    test('loops at the end of the recording', () {
      fakeAsync((async) {
        final h = _Harness(_csv(rows: 100));
        unawaited(h.transport.connect());
        async.elapse(const Duration(milliseconds: 1500));
        expect(h.samples, 150);
        expect(h.lines.where((l) => l == 'S,100000,90000,-25.0'), hasLength(2));
        unawaited(h.transport.dispose());
        async.flushMicrotasks();
      });
    });

    test('playback changes are published', () {
      fakeAsync((async) {
        final h = _Harness(_csv());
        final changes = <DemoPlayback>[];
        h.transport.playbackChanges.listen(changes.add);
        unawaited(h.transport.connect());
        async.elapse(const Duration(seconds: 2));
        h.transport.pause();
        async.flushMicrotasks();
        expect(changes.map((c) => c.position.inSeconds), containsAllInOrder([0, 1, 2]));
        expect(changes.last.paused, isTrue);
        unawaited(h.transport.dispose());
        async.flushMicrotasks();
      });
    });
  });

  test('disconnect stops the timer', () {
    fakeAsync((async) {
      final h = _Harness(_csv());
      unawaited(h.transport.connect());
      async.elapse(const Duration(milliseconds: 300));
      unawaited(h.transport.disconnect());
      async.flushMicrotasks();
      final count = h.lines.length;
      async.elapse(const Duration(seconds: 1));
      expect(h.lines.length, count);
      expect(async.periodicTimerCount, 0);
      unawaited(h.transport.dispose());
      async.flushMicrotasks();
    });
  });

  test('a missing or empty recording fails with recordingUnavailable', () async {
    final missing = DemoReplayTransport(
      recording: DemoRecording.fingerRest,
      loadAsset: (_) async => throw const FileSystemException('missing'),
    );
    await expectLater(
      missing.connect(),
      throwsA(isA<TransportFailure>()
          .having((f) => f.code, 'code', TransportFailureCode.recordingUnavailable)),
    );
    expect(missing.state, BandConnectionState.disconnected);

    final empty = DemoReplayTransport(
      recording: DemoRecording.fingerRest,
      loadAsset: (_) async => 'time_ms,ir\n',
    );
    await expectLater(empty.connect(), throwsA(isA<TransportFailure>()));
    await missing.dispose();
    await empty.dispose();
  });

  test('the real wrist recording announces the wrist sketch', () async {
    final t = DemoReplayTransport(
      recording: DemoRecording.wristBackRest,
      loadAsset: (key) => File(key).readAsString(),
    );
    final first = t.lines.first;
    await t.connect();
    expect(await first, '#MODE wrist');
    expect(t.playback.length.inSeconds, inInclusiveRange(215, 225));
    await t.dispose();
  });
}
