/// LED brightness setting of the band.
///
/// Reported in the `led` and `auto` fields of every `M` line and changed with
/// the commands `a` and `1`–`4`.
enum LedMode {
  auto(null),
  level1(1),
  level2(2),
  level3(3),
  level4(4);

  const LedMode(this.level);

  /// Fixed level 1–4, or `null` in auto mode.
  final int? level;

  bool get isAuto => this == LedMode.auto;

  /// Fixed mode for [level] (1–4), or `null` when out of range.
  static LedMode? fixed(int level) => switch (level) {
        1 => LedMode.level1,
        2 => LedMode.level2,
        3 => LedMode.level3,
        4 => LedMode.level4,
        _ => null,
      };

  /// Value of the `led` column in exported CSV files: `auto` or `1`–`4`.
  String get csvLabel => level?.toString() ?? 'auto';
}

/// Which sketch is running, announced once at start-up with `#MODE ...`.
enum FirmwareMode { finger, wrist }

/// Wrist sketch only: signal used for the rhythm search (`#CH ...`).
enum PpgChannel { ir, red, mix }

/// Category of a `#` status line.
enum LogKind { boot, ok, error, mode, channel, led, reset, info }

/// Body site of a guided measurement.
enum MeasureSite {
  finger,
  wrist;

  /// Sketch that is tuned for this site.
  FirmwareMode get expectedFirmware => switch (this) {
        MeasureSite.finger => FirmwareMode.finger,
        MeasureSite.wrist => FirmwareMode.wrist,
      };
}

/// Signal quality shown to the user.
enum SignalQuality { none, weak, acceptable, excellent }

/// One-line explanation of the current reading, shown under the heart rate.
enum LiveHint {
  saturated,
  noContact,
  motion,
  settling,
  weakSignal,
  stable;

  /// Hints that ask the user to change something.
  bool get isWarning =>
      this == LiveHint.saturated ||
      this == LiveHint.motion ||
      this == LiveHint.weakSignal;
}

/// Connection state of a transport.
enum BandConnectionState { disconnected, connecting, connected }

/// How the app talks to the band.
enum TransportKind { usbSerial, demo, ble }
