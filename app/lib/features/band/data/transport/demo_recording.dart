import '../../domain/enums.dart';

/// Real recordings bundled for the demo mode.
///
/// The files are byte-identical copies of `1_heart_rate/test_data/` (checked by
/// `test/data/recordings_identical_test.dart`).
enum DemoRecording {
  /// Fingertip at rest: 65–72 BPM, quality 100 most of the time.
  fingerRest(
    asset: 'assets/recordings/finger_rest_80s.csv',
    site: MeasureSite.finger,
    length: Duration(seconds: 80),
  ),

  /// Back of the wrist at rest: 61–71 BPM, reading ~60 % of the time.
  wristBackRest(
    asset: 'assets/recordings/wrist_back_rest_221s.csv',
    site: MeasureSite.wrist,
    length: Duration(seconds: 221),
  ),

  /// Inner wrist: no usable pulse. The firmware correctly shows nothing.
  wristInnerNoPulse(
    asset: 'assets/recordings/wrist_inner_no_pulse_134s.csv',
    site: MeasureSite.wrist,
    length: Duration(seconds: 134),
  );

  const DemoRecording({required this.asset, required this.site, required this.length});

  /// Flutter asset key.
  final String asset;

  /// Body site, which is also the sketch the recording was made with.
  final MeasureSite site;

  /// Approximate length, for the picker. The real length comes from the file.
  final Duration length;
}
