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

        expect(PackOper.getPackPath(PackType.Bz2, fromPath, null), fromPath + '.bz2');
        expect(PackOper.getPackPath(PackType.Bz2, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.Gz, fromPath, null), fromPath + '.gz');
        expect(PackOper.getPackPath(PackType.Gz, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.Tar, fromPath, null), fromPath + '.tar');
        expect(PackOper.getPackPath(PackType.Tar, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.TarBz2, fromPath, null), fromPath + '.bz2');
        expect(PackOper.getPackPath(PackType.TarBz2, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.TarGz, fromPath, null), fromPath + '.gz');
        expect(PackOper.getPackPath(PackType.TarGz, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.TarZ, fromPath, null), fromPath + '.Z');
        expect(PackOper.getPackPath(PackType.TarZ, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.Zip, fromPath, null), fromPath + '.zip');
        expect(PackOper.getPackPath(PackType.Zip, fromPath, toPath), toPath);
      });
      test('getPackType - by pack type', () {
        Helper.initFileSystem(fileSystem);

        expect(PackOper.getPackType(PackType.Bz2, null), PackType.Bz2);
        expect(PackOper.getPackType(PackType.Bz2, 'a.txt'), PackType.Bz2);
        expect(PackOper.getPackType(PackType.Gz, null), PackType.Gz);
        expect(PackOper.getPackType(PackType.Gz, 'a.txt'), PackType.Gz);
        expect(PackOper.getPackType(PackType.Tar, null), PackType.Tar);
        expect(PackOper.getPackType(PackType.Tar, 'a.txt'), PackType.Tar);
        expect(PackOper.getPackType(PackType.TarBz2, null), PackType.TarBz2);
        expect(PackOper.getPackType(PackType.TarBz2, 'a.txt'), PackType.TarBz2);
        expect(PackOper.getPackType(PackType.TarGz, null), PackType.TarGz);
        expect(PackOper.getPackType(PackType.TarGz, 'a.txt'), PackType.TarGz);
        expect(PackOper.getPackType(PackType.TarZ, null), PackType.TarZ);
        expect(PackOper.getPackType(PackType.TarZ, 'a.txt'), PackType.TarZ);
        expect(PackOper.getPackType(PackType.Zip, null), PackType.Zip);
        expect(PackOper.getPackType(PackType.Zip, 'a.txt'), PackType.Zip);
      });
      test('getPackType - by file type', () {
        Helper.initFileSystem(fileSystem);

        var path = Path.join('dir', 'a.txt');

        expect(PackOper.getPackType(null, null), null);
        expect(PackOper.getPackType(null, path), null);

        expect(PackOper.getPackType(null, path + '.bz2'), PackType.Bz2);
        expect(PackOper.getPackType(null, path + '.tar.bz2'), PackType.TarBz2);

        expect(PackOper.getPackType(null, path + '.gz'), PackType.Gz);
        expect(PackOper.getPackType(null, path + '.tar.gz'), PackType.TarGz);

        expect(PackOper.getPackType(null, path + '.z'), PackType.Z);
        expect(PackOper.getPackType(null, path + '.Z'), PackType.Z);
        expect(PackOper.getPackType(null, path + '.tar.Z'), PackType.TarZ);
      });
      test('getUnpackPath', () {
        Helper.initFileSystem(fileSystem);

        var dirName = 'dir';
        Path.fileSystem.directory(dirName).createSync();

        var fromPath = Path.join(dirName, 'a.txt');
        var toPath = Path.join(dirName, 'b.txt');

        expect(PackOper.getUnpackPath(PackType.Bz2, fromPath + '.bz2', null), fromPath);
        expect(PackOper.getUnpackPath(PackType.Bz2, fromPath + '.bz2', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.bz2', null), fromPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.bz2', dirName), fromPath);

        expect(PackOper.getUnpackPath(PackType.TarZ, fromPath + '.tar.Z', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(PackType.TarZ, fromPath + '.tar.Z', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.Z', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.Z', dirName), fromPath + '.tar');

        expect(PackOper.getUnpackPath(PackType.TarGz, fromPath + '.tar.gz', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(PackType.TarGz, fromPath + '.tar.gz', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.gz', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.gz', dirName), fromPath + '.tar');
      });
      test('isPackTypeTar', () {
        Helper.initFileSystem(fileSystem);

        expect(PackOper.isPackTypeTar(PackType.Bz2), false);
        expect(PackOper.isPackTypeTar(PackType.Gz), false);

        expect(PackOper.isPackTypeTar(PackType.Zip), false);
        expect(PackOper.isPackTypeTar(PackType.Z), false);

        expect(PackOper.isPackTypeTar(PackType.Tar), true);
        expect(PackOper.isPackTypeTar(PackType.TarBz2), true);

        expect(PackOper.isPackTypeTar(PackType.TarGz), true);
        expect(PackOper.isPackTypeTar(PackType.TarZ), true);
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
            PackType.Zip,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true,
            isListOnly: true,
          );

          expect(Path.fileSystem.file(toPath).existsSync(), false);

          PackOper.archiveSync(
            PackType.Zip,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true
          );

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          expect(fromDir.parent.existsSync(), false);

          PackOper.unarchiveSync(
            PackType.Zip,
            toPath,
            fromDir.parent.path,
            isMove: false,
            isSilent: true,
            isListOnly: true,
          );

          expect(fromDir.existsSync(), false);

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          PackOper.unarchiveSync(
            PackType.Zip,
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
            PackType.Gz,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true,
            isListOnly: true,
          );

          expect(Path.fileSystem.file(toPath).existsSync(), false);

          PackOper.archiveSync(
            PackType.TarGz,
            [fromDir.parent.path, toPath],
            isMove: true,
            isSilent: true
          );

          expect(Path.fileSystem.file(toPath).existsSync(), true);
          expect(fromDir.parent.existsSync(), false);

          PackOper.unarchiveSync(
            PackType.TarGz,
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
