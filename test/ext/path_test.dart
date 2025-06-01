import 'package:test/test.dart';
import 'package:xnx/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Path', () {
      test('adjust', () {
        Helper.initFileSystem(fileSystem);

        final pathSep = Path.separator;

        expect(Path.adjust(null), '');
        expect(Path.adjust(''), '');
        expect(
            Path.adjust(r'\a\bc/def'), '${pathSep}a${pathSep}bc${pathSep}def');
      });
      test('appendCurDirIfPathIsRelative', () {
        Helper.initFileSystem(fileSystem);

        var dir = Path.fileSystem.directory('test')..createSync();
        var oldDir = Path.currentDirectory;
        Path.currentDirectory = dir;
        var curDir = Path.currentDirectoryName;
        var sep = Path.separator;

        expect(
            Path.appendCurDirIfPathIsRelative('File not found: ', 'aaa.txt')
                .contains(curDir),
            true);
        expect(
            Path.appendCurDirIfPathIsRelative(
                    'File not found: ', 'b${sep}aaa.txt')
                .contains(curDir),
            true);
        expect(
            Path.appendCurDirIfPathIsRelative(
                    'File not found: ', '${sep}aaa.txt')
                .contains(curDir),
            false);

        Path.currentDirectory = oldDir;
        dir.deleteSync();
      });
      test('argsToListAndDestination', () {
        Helper.initFileSystem(fileSystem);

        var fromPaths = <String>[];
        expect(
            Path.argsToListAndDestination(fromPaths, path: '', paths: [])
                    .isEmpty &&
                fromPaths.isEmpty,
            true);
        expect(
            Path.argsToListAndDestination(fromPaths, path: 'a', paths: [])
                    .isEmpty &&
                (fromPaths.length == 1),
            true);
        expect(
            Path.argsToListAndDestination(fromPaths, path: '', paths: ['a'])
                    .isEmpty &&
                (fromPaths.length == 1),
            true);
        expect(
            Path.argsToListAndDestination(fromPaths,
                    path: 'a', paths: ['b', 'c']).isEmpty &&
                (fromPaths.length == 3),
            true);
      });
      test('contains', () {
        Helper.initFileSystem(fileSystem);

        expect(Path.contains(r'abc de/fghi jk', r'de/fghi'), true);
        expect(Path.contains(r'Abc dE/Fghi Jk', r'de/fghi'), Path.isWindowsFS);

        if (Path.isWindowsFS) {
          expect(Path.contains(r'Abc dE/Fghi Jk', r'de\fghi'), true);
          expect(Path.contains(r'Abc dE\Fghi Jk', r'de/fghi'), true);
        }
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
      test('getFullPath', () {
        Helper.initFileSystem(fileSystem);

        var curDir = Path.currentDirectoryName;
        var sep = Path.separator;

        expect(Path.equals(Path.getFullPath(''), curDir), true);
        expect(Path.equals(Path.getFullPath('.'), curDir), true);
        expect(Path.equals(Path.getFullPath('..'), Path.dirname(curDir)), true);
        expect(
            Path.equals(Path.getFullPath('..${sep}a${sep}bc'),
                '${Path.dirname(curDir)}${sep}a${sep}bc'),
            true);
        expect(
            Path.equals(Path.getFullPath('${sep}a${sep}bc'), '${sep}a${sep}bc'),
            true);
        expect(
            Path.equals(Path.getFullPath('${sep}Abc.txt'), r'Abc.txt'), true);
        expect(
            Path.equals(Path.getFullPath('$sepСаша.Текст'), '$sepСаша.Текст'),
            true);
      });
      test('replaceAll', () {
        Helper.initFileSystem(fileSystem);

        expect(
            Path.equals(
                Path.replaceAll(
                    r'a \b/c\d/e \b/c\d/ee \b/c\d/e f', r'/b/c/d/e', r'/g/h'),
                r'a /g/h \b/c\d/ee /g/h f'),
            true);
      });
    });
  });
}
