/// Number and time formatting for the UI.
///
/// Numbers are always written with Western digits (72, not ٧٢) in both
/// languages, so nothing here goes through a locale-aware formatter.
abstract final class Fmt {
  /// Rounded whole number, e.g. heart rate.
  static String whole(double value) => value.round().toString();

  /// Fixed decimals, e.g. `31.2`.
  static String fixed(double value, int decimals) => value.toStringAsFixed(decimals);

  /// Thousands separated with commas, e.g. `110,190` for raw ADC values.
  static String grouped(int value) {
    final digits = value.abs().toString();
    final b = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  /// `m:ss`, e.g. `1:05`.
  static String minutesSeconds(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// `HH:mm` on a 24-hour clock.
  static String clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
