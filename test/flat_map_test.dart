import 'package:test/test.dart';
import 'package:xnx/flat_map.dart';

void main() {
  group('Operation', () {
    test('createDirSync/deleteSync', () {
      var flatMap = FlatMap();

      flatMap['a'] = 'b';
      flatMap['b'] = 'c';
      flatMap['c'] = 'd';

      expect(flatMap['a'], 'b');
      expect(flatMap.expand(''), '');
      expect(flatMap.expand('a'), 'd');
    });
  });
}
