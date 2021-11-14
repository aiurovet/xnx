import 'package:test/test.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/operation.dart';

import 'helper.dart';

void main() {
  group('Operation', () {
    test('parse', () {
      var o = Operation(flatMap: FlatMap());

      expect(o.parse(''), OperationType.alwaysFalse);
      expect(o.parse('  '), OperationType.alwaysFalse);
      expect(o.parse('!  '), OperationType.alwaysTrue);
      expect(o.parse('!! \t!  '), OperationType.alwaysTrue);
      expect(o.parse('0'), OperationType.alwaysFalse);
      expect(o.parse('!0'), OperationType.alwaysTrue);
      expect(o.parse(' 0 '), OperationType.alwaysFalse);
      expect(o.parse('1'), OperationType.alwaysTrue);
      expect(o.parse('!  1'), OperationType.alwaysFalse);
      expect(o.parse(' 1 '), OperationType.alwaysTrue);
      expect(o.parse('a'), OperationType.alwaysTrue);
      expect(o.parse(' a '), OperationType.alwaysTrue);
      expect(o.parse(' false '), OperationType.alwaysFalse);
      expect(o.parse(' !false '), OperationType.alwaysTrue);
      expect(o.parse(' true '), OperationType.alwaysTrue);
      expect(o.parse(' !true '), OperationType.alwaysFalse);

      expect(o.parse(' a > b'), OperationType.greater);
      expect(o.parse('a < b '), OperationType.less);
      expect(o.parse('a >= b'), OperationType.greaterOrEquals);
      expect(o.parse('a <= b'), OperationType.lessOrEquals);
      expect(o.parse('a!> b'), OperationType.lessOrEquals);
      expect(o.parse('a!<b'), OperationType.greaterOrEquals);
      expect(o.parse('a<=1'), OperationType.lessOrEquals);
      expect(o.parse('0>=1'), OperationType.greaterOrEquals);

      expect(o.parse('a = b'), OperationType.equals);
      expect(o.parse('1 == 2'), OperationType.equals);
      expect(o.parse('aa != bbb'), OperationType.notEquals);
      expect(o.parse('0 !== 1'), OperationType.notEquals);
      expect((o.parse('ab =/i AB') == OperationType.equals) && !o.isCaseSensitive, true);
      expect((o.parse('ab ==/i AB') == OperationType.equals) && !o.isCaseSensitive, true);
      expect((o.parse('a !=/i ') == OperationType.notEquals) && !o.isCaseSensitive, true);
      expect((o.parse('a !==/i B') == OperationType.notEquals) && !o.isCaseSensitive, true);

      expect((o.parse('a~a') == OperationType.matches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('ab~b') == OperationType.matches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('Ab~/iB') == OperationType.matches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a\nb~/m^[ab]\\\$') == OperationType.matches) && o.isCaseSensitive && !o.isDotAll && o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/s b') == OperationType.matches) && o.isCaseSensitive && o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/u b') == OperationType.matches)  && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a~/is b') == OperationType.matches) && !o.isCaseSensitive && o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/mi b') == OperationType.matches) && !o.isCaseSensitive && !o.isDotAll && o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/iu b') == OperationType.matches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a~/misu b') == OperationType.matches) && !o.isCaseSensitive && o.isDotAll && o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a!~/i') == OperationType.notMatches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a!~/i') == OperationType.notMatches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a!~/u') == OperationType.notMatches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a!~/u') == OperationType.notMatches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a!~/umsi') == OperationType.notMatches) && !o.isCaseSensitive && o.isDotAll && o.isMultiLine && o.isUnicode, true);

      expect((o.parse('-d abc.def') == OperationType.existsDir), true);
      expect((o.parse('-e abc.def') == OperationType.exists), true);
      expect((o.parse('-f abc.def') == OperationType.existsFile), true);
      expect((o.parse('a1.txt -feq s2.txt') == OperationType.fileEquals), true);
      expect((o.parse('a1.txt -fne s2.txt') == OperationType.fileNotEquals), true);
      expect((o.parse('a1.txt -fnw') == OperationType.fileNewer), true);
      expect((o.parse('a1.txt -fnw a2.txt') == OperationType.fileNewer), true);
      expect((o.parse('a1.txt -fol a2.txt') == OperationType.fileOlder), true);
    });

    test('exec - file', () {
      Helper.forEachMemoryFileSystem((fileSystem) {
        Helper.initFileSystem(fileSystem);

        var o = Operation(flatMap: FlatMap());

        Path.fileSystem.directory('dir1').createSync();
        Helper.shortSleep();

        Path.fileSystem.directory('dir2').createSync();
        Helper.shortSleep();
        
        expect(o.exec('dir1 -fol dir2'), true);

        Path.fileSystem.file('file1')..createSync()..writeAsStringSync('A');
        Helper.shortSleep();

        Path.fileSystem.file('file2')..createSync()..writeAsStringSync('Ab');
        Helper.shortSleep();

        expect(o.exec('file1 -fnw file3'), true);
        expect(o.exec('file1 -fol file2'), true);
        expect(o.exec('file3 -fol file2'), true);

        expect(() => o.exec('file1 -fol dir2'), throwsException);
      });
    });

    test('exec - non-file', () {
      var o = Operation(flatMap: FlatMap());

      expect(o.exec(''), false);
      expect(o.exec('  '), false);
      expect(o.exec('0'), false);
      expect(o.exec(' 0 '), false);
      expect(o.exec('1'), true);
      expect(o.exec(' 1 '), true);
      expect(o.exec('a'), true);
      expect(o.exec(' a '), true);
      expect(o.exec(' false '), false);
      expect(o.exec(' true '), true);

      expect(o.exec('a > 1'), true);
      expect(o.exec('a  < 1'), false);
      expect(o.exec('0> 1'), false);
      expect(o.exec('1 >=0'), true);
      expect(o.exec('1<=0'), false);
      expect(o.exec('0<1'), true);
      expect(o.exec('"0!=1"  == "0!=1"'), true);
      expect(o.exec("'0!=1'  == '0!=1'"), true);
      expect(o.exec('"0!=1 " == "0!=1"'), false);
      expect(o.exec("'0!=1 ' == '0!=1'"), false);

      expect(o.exec('aa != bbb'), true);
      expect(o.exec('0 !== 1'), true);
      expect(o.exec('ab =/i AB'), true);
      expect(o.exec('ab ==/i AB'), true);
      expect(o.exec('a !=/i '), true);
      expect(o.exec('a !==/i B'), true);

      expect(o.exec('a~a'), true);
      expect(o.exec('aa~a'), true);
      expect(o.exec('ab~b'), true);
      expect(o.exec('Ab~/iB'), true);
      expect(o.exec('a\nb~/m^[ab]\\\$'), false);
      expect(o.exec('a\nb~/m^[ab]\$'), true);
      expect(o.exec('a~/s b'), false);
      expect(o.exec('a~/u a'), true);
      expect(o.exec('a\na~/im a.a'), false);
      expect(o.exec('a\na~/is a.a'), true);
      expect(o.exec('a~/mi b'), false);
      expect(o.exec('\uFFFF~/iu \uFFFF'), true);
      expect(o.exec('\uFFFF~/misu \uFFFF'), true);
      expect(o.exec('a!~/i'), true);
      expect(o.exec('a!~/i'), true);
      expect(o.exec('a!~/u'), true);
      expect(o.exec('a!~/umsi'), true);
    });
  });
}
