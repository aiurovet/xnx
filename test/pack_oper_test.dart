import 'package:test/test.dart';
//import 'package:xnx/src/ext/path.dart';
//import 'package:xnx/src/pack_oper.dart';

import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Operation', () {
      // test('archiveSync/unarchiveSync', () {
      //   Helper.initFileSystem(fileSystem);

      //   var fromDir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
      //   fromDir.createSync(recursive: true);
      //   Path.fileSystem.directory(Path.join(fromDir.path, 'sub-sub-dir')).createSync();
      //   Path.fileSystem.file(Path.join(fromDir.path, 'a.txt')).createSync();
      //   Path.fileSystem.file(Path.join(fromDir.path, 'b.txt')).createSync();
      //   Path.fileSystem.file(Path.join(fromDir.path, 'c.txt')).createSync();
      //   Path.fileSystem.file(Path.join(fromDir.path, 'd.txt')).createSync();
      //   Path.fileSystem
      //       .file(Path.join(fromDir.path, 'sub-sub-dir', 'a.csv'))
      //       .createSync();

      //   var toDir = Path.fileSystem.directory('zip')..createSync();
      //   var toPath = Path.join(toDir.path, 'test.zip');

      //   PackOper.archiveSync(
      //     PackType.Zip,
      //     [fromDir.parent.path, toPath],
      //     isMove: true,
      //     isSilent: true
      //   );

      //   expect(Path.fileSystem.file(toPath).existsSync(), true);
      //   expect(fromDir.parent.existsSync(), false);

      //   PackOper.unarchiveSync(
      //     PackType.Zip,
      //     fromDir.path,
      //     toPath,
      //     isMove: false,
      //     isSilent: true
      //   );

      //   expect(Path.fileSystem.file(toPath).existsSync(), true);
      //   expect(fromDir.parent.listSync().length, 5);

      //   fromDir.deleteSync(recursive: true);
      //   toDir.deleteSync(recursive: true);
      // });
    });
  });
}
