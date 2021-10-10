import 'package:test/test.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('String', () {
      test('getFullPath', () {
        Helper.initFileSystem(fileSystem);

        var curDir = Path.fileSystem.currentDirectory.path;
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
        Helper.initFileSystem(fileSystem);

        expect(''.isBlank(), true);
        expect(' '.isBlank(), true);
        expect(' \t'.isBlank(), true);
        expect(' \t\n'.isBlank(), true);
        expect(' \t\nA'.isBlank(), false);
      });

      test('parseBool', () {
        Helper.initFileSystem(fileSystem);

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

      test('quote', () {
        Helper.initFileSystem(fileSystem);

        // Env.setEscape(r'^');
        // expect('a ^"\'b\'"c'.quote(), '\'a ^^"^\'b^\'"c\'');

        // Env.setEscape();
        expect(''.quote(), '');
        expect('"'.quote(), '"');
        expect("'".quote(), "'");
        expect(' '.quote(), '" "');
        expect('a b c '.quote(), '"a b c "');
        expect('a"b"c'.quote(), 'a"b"c');
        expect('a "b"c'.quote(), '\'a "b"c\'');
        expect('a \'b\'c'.quote(), '"a \'b\'c"');
        //expect('a \\"\'b\'"c'.quote(), '\'a \\\\"\\\'b\\\'"c\'');
      });

      test('unquote', () {
        Helper.initFileSystem(fileSystem);

        // Env.setEscape(r'^');
        // expect('\'a ^^"^\'b^\'"c\''.unquote(), 'a ^"\'b\'"c');

        // Env.setEscape();
        expect(''.unquote(), '');
        expect('"'.unquote(), '"');
        expect("'".unquote(), "'");
        expect('" "'.unquote(), ' ');
        expect('"a b c "'.unquote(), 'a b c ');
        expect('a"b"c'.unquote(), 'a"b"c');
        // expect('\'a "b"c\''.unquote(), 'a "b"c');
        // expect('"a \'b\'c"'.unquote(), 'a \'b\'c');
        // expect('\'a \\\\"\\\'b\\\'"c\''.unquote(), 'a \\"\'b\'"c');
      });
    });
  });
}
