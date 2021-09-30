import 'package:test/test.dart';
import 'package:xnx/src/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Path', () {
      test('adjust', () {
        Helper.initFileSystem(fileSystem);

        final pathSep = Path.separator;

        expect(Path.adjust(null), '');
        expect(Path.adjust(''), '');
        expect(Path.adjust(r'\a\bc/def'), '${pathSep}a${pathSep}bc${pathSep}def');
      });
      test('argsToListAndDestination', () {
        Helper.initFileSystem(fileSystem);

        var fromPaths = <String>[];
        expect(Path.argsToListAndDestination(fromPaths, path: '', paths: []).isEmpty && fromPaths.isEmpty, true);
        expect(Path.argsToListAndDestination(fromPaths, path: 'a', paths: []).isEmpty && (fromPaths.length == 1), true);
        expect(Path.argsToListAndDestination(fromPaths, path: '', paths: ['a']).isEmpty && (fromPaths.length == 1), true);
        expect(Path.argsToListAndDestination(fromPaths, path: 'a', paths: ['b', 'c']).isEmpty && (fromPaths.length == 3), true);
      });
      test('join', () {
        Helper.initFileSystem(fileSystem);

        expect(Path.join(r'', r''), r'');
        expect(Path.join(r'', r'b'), r'b');

        if (Path.isWindowsFS) {
          expect(Path.join(r'c:', r'b'), r'c:\b');
          expect(Path.join(r'\', r'b'), r'\b');
        }
      });
    });
  });
}
