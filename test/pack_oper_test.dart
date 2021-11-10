import 'package:file/file.dart';
import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/file_oper.dart';
import 'package:xnx/src/pack_oper.dart';

import 'helper.dart';

void doneLocal() {
  getLocalFromDir().parent.deleteIfExistsSync(recursive: true);
  getLocalToDir().deleteIfExistsSync(recursive: true);
}

Directory getLocalFromDir() =>
  Path.fileSystem.directory(Path.join(Path.join(Env.getHome(), 'dir'), 'sub-dir'));

Directory getLocalToDir() =>
  Path.fileSystem.directory(Path.join(Env.getHome(), 'zip'));

List<Directory> initLocal() {
  Env.init();

  var fromDir = getLocalFromDir();
  var toDir = getLocalToDir();

  Path.fileSystem.directory(Path.join(fromDir.path, 'sub-sub-dir')).createSync(recursive: true);
  Path.fileSystem.file(Path.join(fromDir.path, 'a.txt'))..createSync()..writeAsStringSync('A');
  Path.fileSystem.file(Path.join(fromDir.path, 'b.txt'))..createSync()..writeAsStringSync('B B');
  Path.fileSystem.file(Path.join(fromDir.path, 'c.txt'))..createSync()..writeAsStringSync('C C C');
  Path.fileSystem.file(Path.join(fromDir.path, 'd.txt'))..createSync()..writeAsStringSync('D D D D');
  Path.fileSystem.file(Path.join(fromDir.path, 'sub-sub-dir', 'e.csv'))..createSync()..writeAsStringSync('E E');

  toDir.createSync(recursive: true);

  return [fromDir, toDir];
}

void main() {
  var isFirstZipRun = true;
  var isFirstTarGzRun = true;

  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Operation', () {
      test('getPackPath', () {
        Helper.initFileSystem(fileSystem);

        var fromPath = Path.join('dir', 'a.txt');
        var toPath = Path.join('dir', 'b.txt');

        expect(PackOper.getPackPath(PackType.bz2, fromPath, null), fromPath + '.bz2');
        expect(PackOper.getPackPath(PackType.bz2, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.gz, fromPath, null), fromPath + '.gz');
        expect(PackOper.getPackPath(PackType.gz, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.tar, fromPath, null), fromPath + '.tar');
        expect(PackOper.getPackPath(PackType.tar, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.tarBz2, fromPath, null), fromPath + '.bz2');
        expect(PackOper.getPackPath(PackType.tarBz2, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.tarGz, fromPath, null), fromPath + '.gz');
        expect(PackOper.getPackPath(PackType.tarGz, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.tarZ, fromPath, null), fromPath + '.Z');
        expect(PackOper.getPackPath(PackType.tarZ, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.zip, fromPath, null), fromPath + '.zip');
        expect(PackOper.getPackPath(PackType.zip, fromPath, toPath), toPath);
      });
      test('getPackType - by pack type', () {
        Helper.initFileSystem(fileSystem);

        expect(PackOper.getPackType(PackType.bz2, null), PackType.bz2);
        expect(PackOper.getPackType(PackType.bz2, 'a.txt'), PackType.bz2);
        expect(PackOper.getPackType(PackType.gz, null), PackType.gz);
        expect(PackOper.getPackType(PackType.gz, 'a.txt'), PackType.gz);
        expect(PackOper.getPackType(PackType.tar, null), PackType.tar);
        expect(PackOper.getPackType(PackType.tar, 'a.txt'), PackType.tar);
        expect(PackOper.getPackType(PackType.tarBz2, null), PackType.tarBz2);
        expect(PackOper.getPackType(PackType.tarBz2, 'a.txt'), PackType.tarBz2);
        expect(PackOper.getPackType(PackType.tarGz, null), PackType.tarGz);
        expect(PackOper.getPackType(PackType.tarGz, 'a.txt'), PackType.tarGz);
        expect(PackOper.getPackType(PackType.tarZ, null), PackType.tarZ);
        expect(PackOper.getPackType(PackType.tarZ, 'a.txt'), PackType.tarZ);
        expect(PackOper.getPackType(PackType.zip, null), PackType.zip);
        expect(PackOper.getPackType(PackType.zip, 'a.txt'), PackType.zip);
      });
      test('getPackType - by file type', () {
        Helper.initFileSystem(fileSystem);

        var path = Path.join('dir', 'a.txt');

        expect(PackOper.getPackType(null, null), null);
        expect(PackOper.getPackType(null, path), null);

        expect(PackOper.getPackType(null, path + '.bz2'), PackType.bz2);
        expect(PackOper.getPackType(null, path + '.tar.bz2'), PackType.tarBz2);

        expect(PackOper.getPackType(null, path + '.gz'), PackType.gz);
        expect(PackOper.getPackType(null, path + '.tar.gz'), PackType.tarGz);

        expect(PackOper.getPackType(null, path + '.z'), PackType.z);
        expect(PackOper.getPackType(null, path + '.Z'), PackType.z);
        expect(PackOper.getPackType(null, path + '.tar.Z'), PackType.tarZ);
      });
      test('getUnpackPath', () {
        Helper.initFileSystem(fileSystem);

        var dirName = 'dir';
        Path.fileSystem.directory(dirName).createSync();

        var fromPath = Path.join(dirName, 'a.txt');
        var toPath = Path.join(dirName, 'b.txt');

        expect(PackOper.getUnpackPath(PackType.bz2, fromPath + '.bz2', null), fromPath);
        expect(PackOper.getUnpackPath(PackType.bz2, fromPath + '.bz2', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.bz2', null), fromPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.bz2', dirName), fromPath);

        expect(PackOper.getUnpackPath(PackType.tarZ, fromPath + '.tar.Z', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(PackType.tarZ, fromPath + '.tar.Z', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.Z', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.Z', dirName), fromPath + '.tar');

        expect(PackOper.getUnpackPath(PackType.tarGz, fromPath + '.tar.gz', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(PackType.tarGz, fromPath + '.tar.gz', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.gz', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.gz', dirName), fromPath + '.tar');
      });
      test('isPackTypeTar', () {
        Helper.initFileSystem(fileSystem);

        expect(PackOper.isPackTypeTar(PackType.bz2), false);
        expect(PackOper.isPackTypeTar(PackType.gz), false);

        expect(PackOper.isPackTypeTar(PackType.zip), false);
        expect(PackOper.isPackTypeTar(PackType.z), false);

        expect(PackOper.isPackTypeTar(PackType.tar), true);
        expect(PackOper.isPackTypeTar(PackType.tarBz2), true);

        expect(PackOper.isPackTypeTar(PackType.tarGz), true);
        expect(PackOper.isPackTypeTar(PackType.tarZ), true);
      });
      test('archiveSync/unarchiveSync - ZIP - LFS', () {
        // The "archive" package does not seem to be testable on MemoryFileSystem yet
        // So we are testing just once in the current home directory

        if (!isFirstZipRun) {
          return;
        }

        isFirstZipRun = false;

        try {
          var dirList = initLocal();
          var fromDir = dirList[0];
          var toDir = dirList[1];

          var toPath = Path.join(toDir.path, 'test.zip');

          PackOper.archiveSync(
            PackType.zip,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true,
            isListOnly: true,
          );

          expect(Path.fileSystem.file(toPath).existsSync(), false);

          PackOper.archiveSync(
            PackType.zip,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true
          );

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          expect(fromDir.parent.existsSync(), false);

          PackOper.unarchiveSync(
            PackType.zip,
            toPath,
            fromDir.parent.path,
            isMove: false,
            isSilent: true,
            isListOnly: true,
          );

          expect(fromDir.existsSync(), false);

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          PackOper.unarchiveSync(
            PackType.zip,
            toPath,
            fromDir.parent.path,
            isMove: false,
            isSilent: true
          );

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          expect(fromDir.listSync().length, 5);
        }
        finally {
          doneLocal();
        }
      });
      test('archiveSync/unarchiveSync - TAR.GZ - LFS', () {
        // The "archive" package does not seem to be testable on MemoryFileSystem yet
        // So we are testing just once in the current home directory

        if (!isFirstTarGzRun) {
          return;
        }

        isFirstTarGzRun = false;

        try {
          var dirList = initLocal();
          var fromDir = dirList[0];
          var toDir = dirList[1];

          var toPath = Path.join(toDir.path, 'test.tar.gz');
          FileOper.deleteSync([toPath]);

          PackOper.archiveSync(
            PackType.gz,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true,
            isListOnly: true,
          );

          expect(Path.fileSystem.file(toPath).existsSync(), false);

          PackOper.archiveSync(
            PackType.tarGz,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true
          );

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          expect(fromDir.parent.existsSync(), false);

          PackOper.unarchiveSync(
            PackType.tarGz,
            toPath,
            fromDir.parent.path,
            isMove: false,
            isSilent: true
          );

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          expect(fromDir.listSync().length, 5);
        }
        finally {
          doneLocal();
        }
      });
    });
  });
}
