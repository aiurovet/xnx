import 'package:test/test.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/file_oper.dart';

import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Operation', () {
      test('createDirSync/deleteSync', () {
        Helper.initFileSystem(fileSystem);

        FileOper.createDirSync(['', ' ', '\t', 'dir1', Path.join('dir2', 'dir3')], isSilent: true, isListOnly: true);
        expect(Path.fileSystem.directory('dir2').existsSync(), false);

        FileOper.createDirSync(['', ' ', '\t', 'dir1', Path.join('dir2', 'dir3')], isSilent: true);
        Path.fileSystem.file(Path.join('dir1', 'file1.txt')).createSync();

        expect(Path.currentDirectory.listSync().length, 2);
        expect(Path.fileSystem.directory('dir2').listSync().length, 1);

        FileOper.deleteSync([Path.join('dir1', 'file1.txt')], isSilent: true, isListOnly: true);
        expect(Path.fileSystem.directory('dir1').existsSync(), true);

        FileOper.deleteSync([Path.join('dir1', 'file1.txt')], isSilent: true);
        expect(Path.fileSystem.directory('dir1').listSync().length, 0);

        FileOper.deleteSync(['', ' ', '\t', 'dir1', Path.join('dir2', 'dir3')], isSilent: true);
        expect(Path.currentDirectory.listSync().length, 0);

        FileOper.deleteSync(['dir1', 'dir2'], isSilent: true);
      });
      test('listSync', () {
        Helper.initFileSystem(fileSystem);

        FileOper.createDirSync(['', ' ', '\t', 'dir1', Path.join('dir2', 'dir3')], isSilent: true);
        Path.fileSystem.file(Path.join('dir1', 'file1.txt')).createSync();

        expect(FileOper.listSync(['dir1', 'dir2'], isSilent: true).length, 4);

        FileOper.deleteSync(['dir1', 'dir2'], isSilent: true);
      });
    });
  });
}
