import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/glob.dart';
import 'package:xnx/src/ext/path.dart';
import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    Env.init(fileSystem);

    group('Glob', () {
      test('dirname', () {
        final pathSep = Path.separator;

        expect(GlobExt.dirname(''), '');
        expect(GlobExt.dirname('*abc*.def'), '');
        expect(GlobExt.dirname('sub-dir$pathSep*abc*.def'), 'sub-dir');
        expect(GlobExt.dirname('../../sub-dir$pathSep*abc*.def'), '../../sub-dir');
        expect(GlobExt.dirname('sub-dir**$pathSep*abc*.def'), '');
        expect(GlobExt.dirname('top-dir${pathSep}sub-dir**$pathSep*abc*.def'), 'top-dir');

        if (Path.isWindowsFS) {
          expect(GlobExt.dirname('c:sub-dir$pathSep*abc*.def'), 'c:sub-dir');
        }
      });

      test('isRecursive', () {
        final pathSep = Path.separator;

        expect(GlobExt.isRecursive(null), false);
        expect(GlobExt.isRecursive(''), false);
        expect(GlobExt.isRecursive('abc*.def'), false);
        expect(GlobExt.isRecursive('abc**x.def'), false);
        expect(GlobExt.isRecursive('**${pathSep}abc*.def'), true);
        expect(GlobExt.isRecursive('xy**${pathSep}abc*.def'), true);
      });

      test('isGlobPattern', () {
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
