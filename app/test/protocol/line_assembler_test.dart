import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/features/band/data/protocol/line_assembler.dart';

void main() {
  test('joins chunks that split lines anywhere', () {
    final a = LineAssembler();
    expect(a.add('S,1,2,'), isEmpty);
    expect(a.add('3.0\r\nB,8'), ['S,1,2,3.0']);
    expect(a.add('57\r\nM,'), ['B,857']);
  });

  test('several lines in one chunk, CR removed, empty lines skipped', () {
    final a = LineAssembler();
    expect(a.add('#OK\r\n\r\nS,1,2,0.0\nB,900\r\n'), ['#OK', 'S,1,2,0.0', 'B,900']);
  });

  test('an overlong line is dropped up to the next newline', () {
    final a = LineAssembler(maxLineLength: 10);
    expect(a.add('x' * 8), isEmpty);
    expect(a.add('y' * 8), isEmpty); // 16 > 10: discarded
    expect(a.add('zzz\nB,800\n'), ['B,800']);
  });

  test('a complete overlong line is dropped', () {
    final a = LineAssembler(maxLineLength: 5);
    expect(a.add('123456789\nB,1\n'), ['B,1']);
  });

  test('clear forgets a partial line', () {
    final a = LineAssembler();
    a.add('S,1,2');
    a.clear();
    expect(a.add('B,800\n'), ['B,800']);
  });
}
