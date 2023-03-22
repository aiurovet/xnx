import 'package:test/test.dart';
import 'package:xnx/config_file_info.dart';

void main() {
  group('ConfigFileInfo', () {
    test('init', () {
      var x = ConfigFileInfo();

      x.init();
      expect(x.filePath.isEmpty && x.jsonPath.isEmpty, true);
      x.init(filePath: 'a');
      expect(x.filePath.isNotEmpty && x.jsonPath.isEmpty, true);
      x.init(jsonPath: 'a');
      expect(x.filePath.isEmpty && x.jsonPath.isNotEmpty, true);
      x.init(filePath: 'a', jsonPath: 'a');
      expect(x.filePath.isNotEmpty && x.jsonPath.isNotEmpty, true);
    });
    test('parse', () {
      var x = ConfigFileInfo();

      x.parse('a');
      expect(x.filePath.isNotEmpty && x.jsonPath.isEmpty, true);
      x.parse('a?b');
      expect(x.filePath.isNotEmpty && x.jsonPath.isEmpty, true);
      x.parse('a?b=c');
      expect(x.filePath.isNotEmpty && x.jsonPath.isEmpty, true);
      x.parse('a?path=c');
      expect(x.filePath.isNotEmpty && x.jsonPath.isNotEmpty, true);
    });
  });
}
