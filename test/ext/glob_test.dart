import 'package:test/test.dart';
import 'package:xnx/ext/glob.dart';
import 'package:xnx/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Glob', () {
      test('splitPattern', () {
        Helper.initFileSystem(fileSystem);

        final pathSep = Path.separator;

        var parts = GlobExt.splitPattern('');
        expect(parts[0], '');
        expect(parts[1], '');

        parts = GlobExt.splitPattern('*abc*.def');
        expect(parts[0], '');
        expect(parts[1], '*abc*.def');

        parts = GlobExt.splitPattern('sub-dir$pathSep*abc*.def');
        expect(parts[0], 'sub-dir');
        expect(parts[1], '*abc*.def');

        parts = GlobExt.splitPattern('../../sub-dir$pathSep*abc*.def');
        expect(parts[0], '../../sub-dir');
        expect(parts[1], '*abc*.def');

        parts = GlobExt.splitPattern('sub-dir**$pathSep*abc*.def');
        expect(parts[0], '');
        expect(parts[1], 'sub-dir**$pathSep*abc*.def');

        parts = GlobExt.splitPattern('top-dir${pathSep}sub-dir**$pathSep*abc*.def');
        expect(parts[0], 'top-dir');
        expect(parts[1], 'sub-dir**$pathSep*abc*.def');

        if (Path.isWindowsFS) {
          parts = GlobExt.splitPattern('c:sub-dir$pathSep*abc*.def');
          expect(parts[0], 'c:sub-dir');
          expect(parts[1], '*abc*.def');
        }
      });

      test('isRecursive', () {
        Helper.initFileSystem(fileSystem);

        final pathSep = Path.separator;

        expect(GlobExt.isRecursive(null), false);
        expect(GlobExt.isRecursive(''), false);
        expect(GlobExt.isRecursive('abc*.def'), false);
        expect(GlobExt.isRecursive('abc**x.def'), true);
        expect(GlobExt.isRecursive('**${pathSep}abc*.def'), true);
        expect(GlobExt.isRecursive('xy**${pathSep}abc*.def'), true);
      });

      test('isGlobPattern', () {
        Helper.initFileSystem(fileSystem);

        final pathSep = Path.separator;

        expect(GlobExt.isGlobPattern(null), false);
        expect(GlobExt.isGlobPattern(''), false);
        expect(GlobExt.isGlobPattern('abc.def'), false);
        expect(GlobExt.isGlobPattern('abc?.def'), true);
        expect(GlobExt.isGlobPattern('abc*.def'), true);
        expect(GlobExt.isGlobPattern('dir${pathSep}abc.{def,gh}'), true);
      });
    });
  });
}
