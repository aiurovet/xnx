import 'package:test/test.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/string.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('String', () {
      test('getFullPath', () {
        Helper.initFileSystem(fileSystem);

        var curDir = Path.currentDirectoryName;
        var pathSep = Path.separator;

        expect(Path.equals(Path.getFullPath(''), curDir), true);
        expect(Path.equals(Path.getFullPath('.'), curDir), true);
        expect(Path.equals(Path.getFullPath('..'), Path.dirname(curDir)), true);
        expect(
            Path.equals(Path.getFullPath('..${pathSep}a${pathSep}bc'),
                Path.join(Path.dirname(curDir), 'a', 'bc')),
            true);
        expect(
            Path.equals(Path.getFullPath('${pathSep}a${pathSep}bc'),
                '${pathSep}a${pathSep}bc'),
            true);
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

        expect(''.parseBool(), false);
        expect('false'.parseBool(), false);
        expect('0'.parseBool(), false);
        expect('1'.parseBool(), false);
        expect('y'.parseBool(), false);
        expect('Y'.parseBool(), false);
        expect('true'.parseBool(), true);
        expect('True'.parseBool(), true);
        expect('TRUE'.parseBool(), true);
      });

      test('quote', () {
        Helper.initFileSystem(fileSystem);

        expect(''.quote(), '');
        expect(StringExt.quot.quote(), StringExt.quot);
        expect(StringExt.apos.quote(), StringExt.apos);
        expect(' '.quote(), '" "');
        expect('a b c '.quote(), '"a b c "');
        expect('a"b"c'.quote(), 'a"b"c');
        expect('a "b"c'.quote(), '\'a "b"c\'');
        expect('a \'b\'c'.quote(), '"a \'b\'c"');
      });

      test('unquote', () {
        Helper.initFileSystem(fileSystem);

        expect(''.unquote(), '');
        expect(StringExt.apos.unquote(), StringExt.apos);
        expect(StringExt.quot.unquote(), StringExt.quot);
        expect('" "'.unquote(), ' ');
        expect('"a b c "'.unquote(), 'a b c ');
        expect('a"b"c'.unquote(), 'a"b"c');
      });
    });
  });
}
