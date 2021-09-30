import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/transformation.dart';

void main() {
  group('Transformation', () {
    test('exec', () {
      Env.init(null);

      var flatMap = FlatMap();

      var now = DateTime.now().toIso8601String();
      var today = now.substring(0, 10);

      Transformation(flatMap: flatMap, keywords: Keywords())
        .exec(<String, Object?>{
          '{1+2}': [r'=add', 1, 2],
          '{4*3}': [r'=mul', 4, 3],
          '{math}': [r'=div', [r'=mul', 9, 3], [r'=mod', 5, 3]],
          '{today}': [r'=Today'],
          '{year}': [r'=Today', 'yyyy'],
          '{Env}': 'DeV',
          '{env}': [r'=lower', '{Env}'],
          '{ENV}': [r'=Upper', '{Env}'],
          '{ENV,1,1}': [r'=Upper', ['=substr', '{env}', 1, 1]],
          '{env,3,1}': [r'=Lower', ['=substr', '{ENV}', 3, 1]],
          '{weird}': [r'=replaceRegExp', '{Env}elop', '[de]', 'ab', '/gi'],
          '{groups}': [r'=replaceRegExp', 'abcdefghi', '(bc(d))|(g(h))', r'$2\$2\\${4}', '/gi'],
          '{echo}': [r'=run', 'echo "1 2"'],
        });

      expect(flatMap['{1+2}'], '3');
      expect(flatMap['{4*3}'], '12');
      expect(flatMap['{math}'], '13.5');
      expect(flatMap['{today}'], today);
      expect(flatMap['{year}'], today.substring(0, 4));
      expect(flatMap['{env}'], 'dev');
      expect(flatMap['{ENV}'], 'DEV');
      expect(flatMap['{ENV,1,1}'], 'D');
      expect(flatMap['{env,3,1}'], 'v');
      expect(flatMap['{weird}'], 'ababVablop');
      expect(flatMap['{groups}'], r'ad$2\ef$2\hi');
      expect(flatMap['{echo}']?.replaceAll('\r\n', '\n'), '1 2\n');
    });
  });
}
