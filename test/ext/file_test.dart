import 'dart:io';

import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    Env.init(fileSystem);
    var delay = 5;

    group('File', () {
      test('lastModifiedStampSync', () {
        Helper.initFileSystem(fileSystem);

        var outName = 'a.txt';
        var outFile = Path.fileSystem.file(outName);
        expect(outFile.lastModifiedStampSync(), null);
        outFile.writeAsStringSync('Test');
        expect((outFile.lastModifiedStampSync() ?? 0) > 0, true);
        outFile.deleteSync();
      });
      test('compareLastModifiedToSync', () {
        Helper.initFileSystem(fileSystem);

        var outFile1 = Path.fileSystem.file('a.txt');
        outFile1.writeAsStringSync('Test1');

        sleep(Duration(milliseconds: delay));

        var outFile2 = Path.fileSystem.file('b.txt');
        outFile2.writeAsStringSync('Test2');

        expect(outFile2.compareLastModifiedToSync(toFile: outFile1) > 0, true);
        expect(outFile1.compareLastModifiedToSync(toFile: outFile2) < 0, true);
        expect(
            outFile2.compareLastModifiedToSync(toLastModified: DateTime.now()) <
                0,
            true);

        outFile1.deleteSync();
        outFile2.deleteSync();
      });
      test('getIfExistsSync', () {
        Helper.initFileSystem(fileSystem);

        var fileName = 'a.txt';

        expect(FileExt.getIfExistsSync(fileName, canThrow: false), null);

        var file = Path.fileSystem.file(fileName);
        file.writeAsStringSync('Test');

        var path = FileExt.getIfExistsSync(fileName, canThrow: false)?.path;
        expect(Path.equals(path ?? '', file.path), true);
        file.deleteSync();
      });
      test('setTime', () {
        Helper.initFileSystem(fileSystem);

        var now = DateTime.now();
        var nowMS = now.microsecondsSinceEpoch;

        var file = Path.fileSystem.file('a.txt');
        file.writeAsStringSync('Test1');
        file.setTimeSync(modified: now);

        expect((file.lastModifiedStampSync() ?? 0) >= nowMS, true);

        file.deleteSync();
      });
      test('truncateIfExistsSync', () {
        Helper.initFileSystem(fileSystem);

        expect(FileExt.truncateIfExistsSync('', canThrow: false), null);
        expect(FileExt.truncateIfExistsSync(' ', canThrow: false), null);
        expect(FileExt.truncateIfExistsSync('a.txt', canThrow: false) != null,
            true);

        var outName = 'a.txt';
        var outFile = Path.fileSystem.file(outName);
        outFile.writeAsStringSync('Test');
        expect(outFile.lengthSync(), 4);
        expect(FileExt.truncateIfExistsSync(outName, canThrow: false) != null,
            true);
        expect(outFile.existsSync(), false);
      });
      test('xferSync', () {
        Helper.initFileSystem(fileSystem);

        var src = Path.fileSystem.file('a.txt');
        var dst = Path.fileSystem.file('b.txt');

        src.writeAsStringSync('Test');
        sleep(Duration(milliseconds: delay));

        src.xferSync(dst.path,
            isMove: false, isNewerOnly: false, isSilent: true);
        expect(dst.lengthSync(), src.lengthSync());

        var lastMod = dst.lastModifiedSync().microsecondsSinceEpoch;
        expect(lastMod, src.lastModifiedSync().microsecondsSinceEpoch);

        src.xferSync(dst.path, isMove: true, isNewerOnly: true, isSilent: true);
        sleep(Duration(milliseconds: delay));
        expect(dst.lastModifiedSync().microsecondsSinceEpoch, lastMod);
        expect(src.existsSync(), false);

        dst.deleteSync();
      });
    });
  });
}
