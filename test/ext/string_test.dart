import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    Env.init(fileSystem);

    group('String', () {
      test('escapeEscapeChar', () {
        expect(''.escapeEscapeChar(), '');
        expect(r'\'.escapeEscapeChar(), r'\\');
        expect(r'a\bc\'.escapeEscapeChar(), r'a\\bc\\');
      });

      test('getFullPath', () {
        var curDir = Env.fileSystem.currentDirectory.path;
        var pathSep = Path.separator;

        expect(Path.equals(Path.getFullPath(''), curDir), true);
        expect(Path.equals(Path.getFullPath('.'), curDir), true);
        expect(Path.equals(Path.getFullPath('..'), Path.dirname(curDir)), true);
        expect(Path.equals(Path.getFullPath('..${pathSep}a${pathSep}bc'),
            Path.join(Path.dirname(curDir), 'a', 'bc')), true);
        expect(Path.equals(Path.getFullPath('${pathSep}a${pathSep}bc'),
            '${pathSep}a${pathSep}bc'), true);
      });

      test('isBlank', () {
        expect(''.isBlank(), true);
        expect(' '.isBlank(), true);
        expect(' \t'.isBlank(), true);
        expect(' \t\n'.isBlank(), true);
        expect(' \t\n.'.isBlank(), false);
      });

      test('parseBool', () {
        expect(StringExt.parseBool(null), false);
        expect(StringExt.parseBool(''), false);
        expect(StringExt.parseBool('false'), false);
        expect(StringExt.parseBool('0'), false);
        expect(StringExt.parseBool('1'), false);
        expect(StringExt.parseBool('y'), false);
        expect(StringExt.parseBool('Y'), false);
        expect(StringExt.parseBool('true'), true);
        expect(StringExt.parseBool('True'), true);
        expect(StringExt.parseBool('TRUE'), true);
      });

      test('splitCommandLine', () {
        expect(''.splitCommandLine(), {0: [''], 1: []});
        expect('a'.splitCommandLine(), {0: ['a'], 1: []});
        expect('"a b"'.splitCommandLine(), {0: ['a b'], 1: []});
        expect('"a b" "cd e" fgh \'i"j\''.splitCommandLine(),
            {0: ['a b'], 1: ['cd e', 'fgh', 'i"j']});
      });

      test('quote', () {
        expect(''.quote(isSingle: false), '""');
        expect(''.quote(isSingle: true), '\'\'');
        expect('a b c '.quote(isSingle: false), '"a b c "');
        expect('a b c '.quote(isSingle: true), '\'a b c \'');
        expect('a"b"c'.quote(isSingle: false), '"a\\"b\\"c"');
        expect('a"b"c'.quote(isSingle: true), '\'a"b"c\'');
        expect('a\'b\'c'.quote(isSingle: false), '"a\'b\'c"');
        expect('a\'b\'c'.quote(isSingle: true), '\'a\\\'b\\\'c\'');
      });

      test('tokensOf', () {
        expect(''.tokensOf(''), 0);
        expect(''.tokensOf('.'), 0);
        expect('a.b.c'.tokensOf('abcdefg'), 0);
        expect('a.b.c'.tokensOf(''), 0);
        expect('a.b.c'.tokensOf('.'), 2);
      });

      test('unquote', () {
        expect('""'.unquote(), '');
        expect('\'\''.unquote(), '');
        expect('"a b c "'.unquote(), 'a b c ');
        expect('\'a b c \''.unquote(), 'a b c ');
        expect('"a\\"b\\"c"'.unquote(), 'a"b"c');
        expect('\'a"b"c\''.unquote(), 'a"b"c');
        expect('"a\'b\'c"'.unquote(), 'a\'b\'c');
        expect('\'a\\\'b\\\'c\''.unquote(), 'a\'b\'c');
        expect('"abc'.unquote(), '"abc');
        expect('\'abc'.unquote(), '\'abc');
        expect('abca'.unquote(), 'abca');
      });
    });
  });
}
