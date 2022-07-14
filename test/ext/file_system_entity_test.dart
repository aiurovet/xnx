import 'dart:io';

import 'package:test/test.dart';
import 'package:xnx/ext/file_system_entity.dart';
import 'package:xnx/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    var delay = Duration(milliseconds: 5);

    group('File System Entity', () {
      test('deleteIfExistsSync', () {
        Helper.initFileSystem(fileSystem);

        var dir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
        dir.createSync(recursive: true);

        var file = Path.fileSystem.file(Path.join(dir.path, 'a.txt'));
        file.writeAsStringSync('Test1');

        file.deleteIfExistsSync();
        expect(file.existsSync(), false);

        dir.deleteIfExistsSync(recursive: true);
        sleep(delay);

        expect(dir.existsSync(), false);
      });
    });
  });
}
