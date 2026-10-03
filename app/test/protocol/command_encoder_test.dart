import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/command_encoder.dart';
import 'package:repocare_band/features/band/domain/enums.dart';

void main() {
  const encoder = CommandEncoder();

  test('every command is the single character from SERIAL_PROTOCOL.md', () {
    expect(encoder.encode(BandCommand.autoLed), 'a');
    expect(encoder.encode(BandCommand.led1), '1');
    expect(encoder.encode(BandCommand.led2), '2');
    expect(encoder.encode(BandCommand.led3), '3');
    expect(encoder.encode(BandCommand.led4), '4');
    expect(encoder.encode(BandCommand.reset), 'r');
    for (final c in BandCommand.values) {
      expect(encoder.encode(c), hasLength(1));
    }
  });

  test('LED mode maps to the matching command', () {
    expect(BandCommand.forLedMode(LedMode.auto), BandCommand.autoLed);
    for (final mode in LedMode.values.where((m) => !m.isAuto)) {
      expect(BandCommand.forLedMode(mode).wire, '${mode.level}');
    }
  });
}
