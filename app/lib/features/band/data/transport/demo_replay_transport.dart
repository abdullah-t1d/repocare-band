import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/band_constants.dart';
import '../../domain/enums.dart';
import '../protocol/csv_row_to_lines.dart';
import 'band_transport.dart';
import 'demo_recording.dart';

/// Loads a text asset; injected so tests do not need the asset bundle.
typedef AssetLoader = Future<String> Function(String key);

Future<String> _loadFromBundle(String key) => rootBundle.loadString(key);

/// Playback position and controls of a [DemoReplayTransport].
@immutable
class DemoPlayback {
  const DemoPlayback({
    required this.recording,
    this.position = Duration.zero,
    this.length = Duration.zero,
    this.paused = false,
    this.speed = 1,
  });

  final DemoRecording recording;
  final Duration position;
  final Duration length;
  final bool paused;

  /// Playback speed: 1 = real time (100 rows per second), 2 = double.
  final int speed;

  /// 0–1.
  double get progress =>
      length.inMilliseconds == 0 ? 0 : position.inMilliseconds / length.inMilliseconds;

  DemoPlayback copyWith({Duration? position, Duration? length, bool? paused, int? speed}) =>
      DemoPlayback(
        recording: recording,
        position: position ?? this.position,
        length: length ?? this.length,
        paused: paused ?? this.paused,
        speed: speed ?? this.speed,
      );

  @override
  bool operator ==(Object other) =>
      other is DemoPlayback &&
      other.recording == recording &&
      other.position == position &&
      other.length == length &&
      other.paused == paused &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(recording, position, length, paused, speed);
}

/// Replays a real recording as if the band were connected.
///
/// Each CSV row is turned back into the protocol lines the firmware sent
/// ([RecordingToLines]) and emitted at the recording's own rate of 100 rows
/// per second (or faster with [setSpeed]). At the end the recording starts
/// again, so a demo can run unattended.
///
/// On connect the transport sends `#MODE finger` or `#MODE wrist`, the line
/// the matching sketch prints at start-up. Commands are accepted but have no
/// effect: a recording cannot change its LED current.
class DemoReplayTransport extends BandTransportBase {
  DemoReplayTransport({
    required this.recording,
    AssetLoader loadAsset = _loadFromBundle,
    this.tickInterval = const Duration(milliseconds: 20),
  })  : _loadAsset = loadAsset,
        _playback = DemoPlayback(recording: recording);

  /// Allowed values for [setSpeed].
  static const List<int> speeds = [1, 2];

  final DemoRecording recording;

  /// How often rows are emitted. 20 ms = 2 rows per tick at 1x.
  final Duration tickInterval;

  final AssetLoader _loadAsset;
  final RecordingToLines _converter = RecordingToLines();
  final StreamController<DemoPlayback> _playbackChanges =
      StreamController<DemoPlayback>.broadcast();

  List<RecordingRow> _rows = const [];
  Timer? _timer;
  int _next = 0;
  double _carry = 0;
  DemoPlayback _playback;

  @override
  TransportKind get kind => TransportKind.demo;

  DemoPlayback get playback => _playback;

  /// Emitted on every control change and once per second of playback.
  Stream<DemoPlayback> get playbackChanges => _playbackChanges.stream;

  @override
  Future<void> connect() async {
    if (state != BandConnectionState.disconnected || isDisposed) return;
    setState(BandConnectionState.connecting);
    try {
      if (_rows.isEmpty) _rows = parseRecording(await _loadAsset(recording.asset));
    } on Object catch (e) {
      setState(BandConnectionState.disconnected);
      throw TransportFailure(TransportFailureCode.recordingUnavailable, '$e');
    }
    if (_rows.isEmpty) {
      setState(BandConnectionState.disconnected);
      throw TransportFailure(TransportFailureCode.recordingUnavailable, recording.asset);
    }
    _rewind();
    _setPlayback(_playback.copyWith(length: _rowsToDuration(_rows.length), paused: false));
    setState(BandConnectionState.connected);
    emitLine('#MODE ${recording.site.expectedFirmware.name}');
    _timer = Timer.periodic(tickInterval, (_) => _tick());
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    setState(BandConnectionState.disconnected);
  }

  @override
  Future<void> send(String command) async {
    // A recording cannot react to commands.
  }

  void pause() {
    if (_playback.paused) return;
    _setPlayback(_playback.copyWith(paused: true));
  }

  void resume() {
    if (!_playback.paused) return;
    _setPlayback(_playback.copyWith(paused: false));
  }

  /// Starts the recording again from the first row.
  void restart() {
    _rewind();
    _setPlayback(_playback.copyWith(position: Duration.zero));
  }

  void setSpeed(int speed) {
    if (!speeds.contains(speed)) throw ArgumentError.value(speed, 'speed', 'must be one of $speeds');
    _setPlayback(_playback.copyWith(speed: speed));
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    unawaited(_playbackChanges.close());
  }

  void _tick() {
    if (_playback.paused || state != BandConnectionState.connected) return;
    _carry += BandConstants.sampleRateHz * tickInterval.inMicroseconds / 1e6 * _playback.speed;
    final count = _carry.floor();
    _carry -= count;
    for (var i = 0; i < count; i++) {
      if (_next >= _rows.length) _rewind();
      _converter.linesFor(_rows[_next]).forEach(emitLine);
      _next++;
    }
    final position = _rowsToDuration(_next);
    if (position.inSeconds != _playback.position.inSeconds) {
      _setPlayback(_playback.copyWith(position: position));
    }
  }

  void _rewind() {
    _next = 0;
    _carry = 0;
    _converter.reset();
  }

  void _setPlayback(DemoPlayback value) {
    _playback = value;
    if (!_playbackChanges.isClosed) _playbackChanges.add(value);
  }

  static Duration _rowsToDuration(int rows) =>
      Duration(milliseconds: rows * 1000 ~/ BandConstants.sampleRateHz);
}
