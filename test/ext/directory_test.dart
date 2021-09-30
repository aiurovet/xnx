import 'package:test/test.dart';
import 'package:xnx/src/ext/directory.dart';
import 'package:xnx/src/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Directory', () {
      test('appendPathSeparator', () {
        Helper.initFileSystem(fileSystem);
        var sep = Path.separator;

        expect(DirectoryExt.appendPathSeparator(''), '');
        expect(DirectoryExt.appendPathSeparator(' '), ' ');
        expect(DirectoryExt.appendPathSeparator(sep), sep);

        var dir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
        expect(
            DirectoryExt.appendPathSeparator(dir.path), 'dir${sep}sub-dir$sep');
      });
      test('entityListSync', () {
        Helper.initFileSystem(fileSystem);

        var dir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
        dir.createSync(recursive: true);

        Path.fileSystem.directory(Path.join(dir.path, 'sub-sub-dir')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'a.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'b.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'c.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'd.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'sub-sub-dir', 'a.csv')).createSync();

        expect(
          dir.entityListSync('',
            checkExists: true, takeDirs: true, takeFiles: false).length,
          1);
        expect(
          dir.entityListSync('',
            checkExists: true, takeDirs: false, takeFiles: true).length,
          4);
        expect(
          dir.entityListSync('',
            checkExists: true, takeDirs: true, takeFiles: true).length,
          5);
        expect(
          dir.entityListSync('*d*',
            checkExists: true, takeDirs: true, takeFiles: true).length,
          2);
        expect(
          dir.entityListSync('sub-sub-dir',
            checkExists: true, takeDirs: true, takeFiles: true).length,
          1);

        dir.deleteSync(recursive: true);
      });
      test('entityListExSync', () {
        Helper.initFileSystem(fileSystem);

        var dir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
        dir.createSync(recursive: true);

        Path.fileSystem.directory(Path.join(dir.path, 'sub-sub-dir')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'a.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'b.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'c.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'd.txt')).createSync();

        expect(
          DirectoryExt.entityListExSync(dir.path,
            checkExists: true, takeDirs: true, takeFiles: false).length,
          1);
        expect(
          DirectoryExt.entityListExSync(dir.path,
            checkExists: true, takeDirs: false, takeFiles: true).length,
          4);
        expect(
          DirectoryExt.entityListExSync(dir.path,
            checkExists: true, takeDirs: true, takeFiles: true).length,
          5);

        dir.deleteSync(recursive: true);
      });
      test('pathListSync', () {
        Helper.initFileSystem(fileSystem);

        var dir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
        dir.createSync(recursive: true);

        Path.fileSystem.directory(Path.join(dir.path, 'sub-sub-dir')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'a.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'b.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'c.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'd.txt')).createSync();
        Path.fileSystem.file(Path.join(dir.path, 'sub-sub-dir', 'a.csv')).createSync();

        expect(
          dir.pathListSync('',
            checkExists: true, takeDirs: true, takeFiles: false).length,
          1);
        expect(
          dir.pathListSync('*.txt',
            checkExists: true, takeDirs: false, takeFiles: true).length,
          4);
        expect(
          dir.parent.pathListSync('**/*a*',
            checkExists: true, takeDirs: true, takeFiles: true).length,
          2);

        dir.deleteSync(recursive: true);
      });
    });
  });
}
