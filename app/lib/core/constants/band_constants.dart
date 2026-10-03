/// Numbers shared by the protocol, the UI and the tests.
///
/// Values marked "firmware" mirror constants in
/// `1_heart_rate/repocare_*/repocare_*.ino` and must stay in sync with them.
abstract final class BandConstants {
  /// USB serial speed used by both sketches.
  static const int baudRate = 115200;

  /// `S` lines per second (firmware: 400 Hz averaged by 4).
  static const int sampleRateHz = 100;

  /// Largest value of the MAX30102 18-bit ADC.
  static const int adcMax = 262143;

  /// IR level above which the firmware reports `saturated = 1` (firmware).
  static const int saturationIr = 250000;

  /// Clean beats kept by the firmware for HRV (firmware `N_IBI`).
  static const int maxStoredBeats = 12;

  /// Shortest beat-to-beat interval the firmware accepts, in ms (firmware).
  static const int minIbiMs = 300;

  /// Longest beat-to-beat interval the firmware accepts, in ms (firmware).
  static const int maxIbiMs = 2000;

  /// Quality at or above this is shown as "excellent".
  static const int qualityExcellent = 75;

  /// Quality at or above this is shown as "acceptable"; below is "weak".
  static const int qualityAcceptable = 45;

  /// Length of the live waveform window.
  static const Duration waveformWindow = Duration(seconds: 6);

  /// Number of samples in the live waveform window.
  static const int waveformSamples = 600;

  /// The firmware reports a beat ~150 ms after its upstroke; the beat tick on
  /// the waveform is moved back by this many samples.
  static const int beatMarkerDelaySamples = 15;

  /// Length of the BPM trend chart.
  static const Duration trendWindow = Duration(minutes: 2);

  /// Number of firmware log lines kept for the raw panel.
  static const int maxLogLines = 6;
}
