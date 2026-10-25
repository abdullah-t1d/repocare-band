import '../../domain/enums.dart';

/// Commands accepted by the band. Each is sent as a single character.
enum BandCommand {
  /// Auto brightness.
  autoLed('a'),

  /// Fixed brightness, ~6 mA.
  led1('1'),

  /// Fixed brightness, ~12 mA.
  led2('2'),

  /// Fixed brightness, ~25 mA.
  led3('3'),

  /// Fixed brightness, ~50 mA.
  led4('4'),

  /// Reset the analysis.
  reset('r'),

  /// Finger profile (combined firmware v3.0); replies `#MODE finger`.
  fingerProfile('f'),

  /// Wrist profile (combined firmware v3.0); replies `#MODE wrist`.
  wristProfile('w');

  const BandCommand(this.wire);

  /// Character sent over the transport.
  final String wire;

  /// Command that selects [mode].
  static BandCommand forLedMode(LedMode mode) => switch (mode) {
        LedMode.auto => autoLed,
        LedMode.level1 => led1,
        LedMode.level2 => led2,
        LedMode.level3 => led3,
        LedMode.level4 => led4,
      };

  /// Command that switches the firmware to the profile for [site].
  static BandCommand forSite(MeasureSite site) => switch (site) {
        MeasureSite.finger => fingerProfile,
        MeasureSite.wrist => wristProfile,
      };
}

/// Turns [BandCommand]s into the text written to the transport.
///
/// Kept separate from the transports so a future firmware (for example over
/// BLE) can change the encoding in one place.
class CommandEncoder {
  const CommandEncoder();

  String encode(BandCommand command) => command.wire;
}
