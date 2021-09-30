import 'package:test/test.dart';
import 'package:xnx/src/config_key_data.dart';

void main() {
  group('ConfigKeyData', () {
    test('constructor', () {
      expect(ConfigKeyData(null, null).key, null);
      expect(ConfigKeyData(null, null).data, null);
      expect(ConfigKeyData('', null).key, '');
      expect(ConfigKeyData('a', null).key, 'a');
      expect(ConfigKeyData('', true).data, true);
      expect(ConfigKeyData('a', true).data, true);
    });
  });
}
