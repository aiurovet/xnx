import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:doul/ext/string.dart';
import 'package:path/path.dart' as Path;

import 'file_oper.dart';

class ArchOper {

  //////////////////////////////////////////////////////////////////////////////

  static void zipSync({String fromPath, List<String> fromPaths,
    int start = 0, int end, String toPath,
    bool isMove = false, bool isSilent = false}) {

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    var toFile = File(toPath ?? fromPaths[end]);
    print('Creating archive "${toFile.path}"');

    var toDir = Directory(Path.dirname(toFile.path));
    var hadToDir = toDir.existsSync();

    if (!hadToDir) {
      toDir.createSync(recursive: true);
    }
    else if (toFile.existsSync()) {
      toFile.deleteSync();
    }

    var encoder = ZipFileEncoder();
    encoder.create(toFile.path);

    FileOper.listSync(path: fromPath, paths: fromPaths, start: start, end: end,
      repeats: (isMove ? 2 : 1), isSilent: isSilent, isSorted: true, isMinimal: true,
      listProc: (entities, entityNo, repeatNo, subPath) {
        if (entityNo < 0) { // empty list
          if (!isSilent) {
            encoder.close();

            if (toFile.existsSync()) {
              toFile.deleteSync();
            }

            if (!hadToDir) {
              toDir.deleteSync(recursive: true);
            }

            throw Exception('Source was not found: "${fromPath ?? fromPaths[start] ?? StringExt.EMPTY}"');
          }
        }

        var entity = entities[entityNo];
        var isDir = (entity is Directory);

        if (repeatNo == 0) {
          if (!isSilent) {
            print('Adding ${isDir ? 'dir' : 'file'} "${entity.path}"');
          }

          if (isDir) {
            encoder.addDirectory(entity, includeDirName: (subPath.length > 0));
          }
          else {
            encoder.addFile(entity);
          }
        }
        else if (isMove && (repeatNo == 1)) {
          if (entity.existsSync()) {
            if (!isSilent) {
              print('Deleting ${isDir ? 'dir' : 'file'} "${entity.path}"');
            }
            entity.deleteSync(recursive: true);
          }
        }

        return true;
      }
    );

    if (!isSilent) {
      print(StringExt.EMPTY);
    }

    encoder.close();
  }

  //////////////////////////////////////////////////////////////////////////////

  static void unzipSync(String fromPath, String toDirName,
    {bool isMove = false, bool isSilent = false}) {

    final fromFile = (fromPath == null ? null : File(fromPath));

    if (!(fromFile?.existsSync() ?? false)) {
      throw Exception('Archive was not found: "${fromPath ?? StringExt.EMPTY}"');
    }

    final toDir = Directory(toDirName);

    if (!isSilent) {
      print('Decompressing "${fromPath}" to "${toDirName}"');
    }

    final toDirExisted = toDir.existsSync();
    final bytes = fromFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    try {
      if (!toDirExisted) {
        toDir.createSync(recursive: true);
      }

      for (final entity in archive) {
        final toPath = Path.join(toDirName, entity.name);
        final isFile = entity.isFile;

        if (!isSilent) {
          print('Extracting ${isFile ? 'file' : 'dir'} "${entity.name}"');
        }

        if (isFile) {
          File(toPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entity.content);
        } else {
          Directory(toPath)
            ..createSync(recursive: true);
        }
      }

      if (isMove ?? false) {
        if (!isSilent) {
          print('Deleting archive "${fromPath}"');
        }

        fromFile.deleteSync();
      }
    }
    catch (e) {
      if (!toDirExisted) {
        toDir.deleteSync(recursive: true);
      }

      rethrow;
    }

    if (!isSilent) {
      print(StringExt.EMPTY);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}