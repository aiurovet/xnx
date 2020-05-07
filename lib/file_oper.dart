import 'dart:io';
import 'package:path/path.dart' as Path;

import 'ext/glob.dart';

class FileOper {

  ////////////////////////////////////////////////////////////////////////////

  static void copySync(String fromPath, String toPath, {bool isMove, bool isNewerOnly}) {
    // Ensuring flags

    isMove ??= false;
    isNewerOnly ??= false;

    // If source is existing file, then just copy it

    if (File(fromPath).existsSync()) {
      copyFileSync(fromPath, toPath, isMove: isMove, isNewerOnly: isNewerOnly);
      return;
    }

    // If source is existing directory, then append wildcard

    var fromDirName = fromPath;

    if (Directory(fromDirName).existsSync()) {
      fromPath = Path.join(fromDirName, '*');
    }
    else {
      fromDirName = Path.dirname(fromPath);

      // If source directory does not exist, ensure the parent directory exists

      if (!Directory(fromDirName).existsSync()) {
        throw Exception('Source directory was not found: "${fromDirName}"');
      }
    }

    // Get the top directory prefix length

    var fromDirPrefixLen = fromDirName.length;

    if (fromDirPrefixLen < fromPath.length) {
      ++fromDirPrefixLen;
    }

    // Get list of all files and directories matching fromPath pattern

    var filter = GlobExt.toGlob(fromPath);
    var fromEntities = filter.listSync(root: fromPath);

    // Copy files matching search pattern

    fromEntities.forEach((fromEntity) {
      var fromPath = fromEntity.path;
      var subPath = fromPath;
      var toDirName = toPath;

      if (subPath.length > fromDirPrefixLen) {
        subPath = subPath.substring(fromDirPrefixLen);
        toDirName = Path.join(toPath, subPath);
      }

      if (fromEntity is File) {
        copyFileSync(fromPath, toDirName, isMove: isMove, isNewerOnly: isNewerOnly);
      }
      else if ((fromEntity is Directory)) {
        if (fromPath == toDirName) {
          throw Exception('Cannot ${isMove ?? 0 ? 'move': 'copy'} directory onto itself: "${fromPath}"');
        }
        if (!isMove) {
          createDirectorySync(toDirName);
        }
      }
    });

    // Delete source directory in case of move and all files have been moved

    if (isMove) {
      var fromDir = Directory(fromDirName);
      var hasFiles = fromDir.listSync(recursive: true).any((x) => (x is File));

      if (!hasFiles && (fromDirName != toPath)) {
        deleteDirectorySync(fromDirName);
      }
    }
  }

  ////////////////////////////////////////////////////////////////////////////

  static void copyFileSync(String fromPath, String toPath, {bool isMove, bool isNewerOnly}) {
    // Ensuring flags

    isMove ??= false;
    isNewerOnly ??= false;

    // Ensuring source file exists

    var fromFile = File(fromPath);
    var fromStat = fromFile.statSync();

    if (fromStat.type == FileSystemEntityType.notFound) {
      throw Exception('Copy failed, as source file was not found: "${fromFile.path}"');
    }

    // Getting last modification time and destination path and directory

    var canDo = true;
    var isToDir = Directory(toPath).existsSync();
    var isToDirValid = isToDir;
    var toPathEx = (isToDir ? Path.join(toPath, Path.basename(fromPath)) : toPath);
    var toDirName = (isToDir ? toPath : Path.dirname(toPath));

    // Setting operation flag depending on whether the destination is newer or not

    if (isNewerOnly) {
      var toFile = File(toPathEx);
      var toStat = toFile.statSync();

      if (toStat.type != FileSystemEntityType.notFound) {
        isToDirValid = true;

        if (toStat.modified.microsecondsSinceEpoch >= fromStat.modified.microsecondsSinceEpoch) {
          canDo = false;
        }
      }
    }

    if (!isToDirValid) {
      createDirectorySync(toDirName);
    }

    if (isMove) {
      if (canDo) {
        fromFile.renameSync(toPathEx);
      }
      else {
        fromFile.deleteSync();
      }
    }
    else if (canDo) {
      fromFile.copySync(toPathEx);
    }
  }

  ////////////////////////////////////////////////////////////////////////////

  static void createDirectorySync(String dirName, {bool recursive = true}) {
    var dir = Directory(dirName);

    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  ////////////////////////////////////////////////////////////////////////////

  static void deleteDirectorySync(String dirName) {
    var dir = Directory(dirName);

    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  ////////////////////////////////////////////////////////////////////////////

}