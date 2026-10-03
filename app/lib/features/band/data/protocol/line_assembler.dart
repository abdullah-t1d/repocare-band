/// Turns arbitrary text chunks from a byte stream into complete lines.
///
/// Serial data arrives in pieces that do not follow line boundaries. Lines
/// end with `\n` (the firmware's `println` sends `\r\n`); the `\r` is removed.
/// Empty lines are skipped.
///
/// A line longer than [maxLineLength] is garbage (for example a missing line
/// ending after a board reset). It is dropped up to the next `\n` so memory
/// never grows without limit.
class LineAssembler {
  LineAssembler({this.maxLineLength = 256}) : assert(maxLineLength > 0, 'must be positive');

  /// The longest real line (`M`) is about 70 characters.
  final int maxLineLength;

  final StringBuffer _pending = StringBuffer();
  bool _discarding = false;

  /// Adds [chunk] and returns the lines it completed.
  List<String> add(String chunk) {
    final parts = chunk.split('\n');
    final lines = <String>[];
    for (var i = 0; i < parts.length - 1; i++) {
      _pending.write(parts[i]);
      final line = _pending.toString();
      _pending.clear();
      if (_discarding || line.length > maxLineLength) {
        _discarding = false;
        continue;
      }
      final clean = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
      if (clean.isNotEmpty) lines.add(clean);
    }
    _pending.write(parts.last);
    if (_pending.length > maxLineLength) {
      _pending.clear();
      _discarding = true;
    }
    return lines;
  }

  /// Forgets any incomplete line, e.g. after reconnecting.
  void clear() {
    _pending.clear();
    _discarding = false;
  }
}
