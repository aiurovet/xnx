import 'dart:io';
import 'package:doul/ext/string.dart';
import 'package:path/path.dart' as Path;

import 'ext/glob.dart';

class FileOper {

  //////////////////////////////////////////////////////////////////////////////

  static void copySync(String fromPath, String toPath, {bool move = false, bool newerOnly = false}) {
    var isToFile = File(toPath).existsSync();

    listSync(fromPath, repeats: 2, filesFirst: true, suppressErrors: false, listProc: (entities, entityNo, repeatNo, subPath) {
      if (entities.isEmpty) {
        throw Exception('Source was not found: "${fromPath}"');
      }

      var entity = entities[entityNo];
      var fromPathEx = entity.path;
      var toDirName = (isToFile ? null : Path.join(toPath, subPath));
      var toPathEx = (isToFile ? toPath : Path.join(toDirName, Path.basename(fromPathEx)));

      if ((repeatNo == 0) && (entity is File)) {
        copyFileSync(fromPathEx, toPathEx, move: move, newerOnly: newerOnly);
        return true;
      }
      else if ((repeatNo == 1) && (entity is Directory)) {
        if (!entity.existsSync()) {
          if (!move) {
            createDirectorySync(toDirName);
          }
        }
      }

      return true;
    });

    // If source is existing file, then just copy it

    if (File(fromPath).existsSync()) {
      copyFileSync(fromPath, toPath, move: move, newerOnly: newerOnly);
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
        copyFileSync(fromPath, toDirName, move: move, newerOnly: newerOnly);
      }
      else if ((fromEntity is Directory)) {
        if (fromPath == toDirName) {
          throw Exception('Cannot ${move ?? 0 ? 'move': 'copy'} directory onto itself: "${fromPath}"');
        }
        if (!move) {
          createDirectorySync(toDirName);
        }
      }
    });

    // Delete source directory in case of move and all files have been moved

    if (move) {
      var fromDir = Directory(fromDirName);
      var hasFiles = fromDir.listSync(recursive: true).any((x) => (x is File));

      if (!hasFiles && (fromDirName != toPath)) {
        deleteDirectorySync(fromDirName);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void copyFileSync(String fromPath, String toPath, {bool move = false, bool newerOnly = false}) {
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

    if (newerOnly) {
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

    if (move) {
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

  //////////////////////////////////////////////////////////////////////////////

  static void createDirectorySync(String dirName, {bool recursive = true}) {
    var dir = Directory(dirName);

    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void deleteDirectorySync(String dirName) {
    var dir = Directory(dirName);

    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> listSync(
      String path, {
      int repeats = 1,
      bool sorted = true,
      bool filesFirst = false,
      bool suppressErrors = false,
      bool Function(List<FileSystemEntity> entities, int entityNo, int repeatNo, String subPath) listProc,
      int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc
    }) {
    // Get list of file system entities to walk through

    var dirName = path;
    var dirNameLen = dirName.length;

    var entities = <FileSystemEntity>[];

    var dir = Directory(dirName);

    // If path is an existing directory, then grab all of it's children

    if (dir.existsSync()) {
      ++dirNameLen;
      path = StringExt.EMPTY;
      entities = dir.listSync(recursive: true);
    }
    else {
      var file = File(path);

      // If path is an existing file, then the list is just a single file

      if (file.existsSync()) {
        dirName = Path.dirname(path);
        dirNameLen = dirName.length + 1;
        path = path.substring(dirNameLen);
        entities.add(file);
      }
      else {
        // If we've got here, then either path contains wildcard(s), or it
        // simply does not exist

        dirName = GlobExt.getDirectoryName(path);

        // If source directory does not exist, ensure the parent directory exists

        dir = Directory(dirName);

        if (!dir.existsSync()) {
          if (suppressErrors ?? false) {
            return null;
          }
          else {
            throw Exception('Top source directory was not found: "${dirName}"');
          }
        }

        dirNameLen = dirName.length + 1;
        path = path.substring(dirNameLen);

        // Get the list of all files and directories matching path pattern

        var filter = GlobExt.toGlob(path);
        entities = filter.listSync(root: dirName);
      }
    }

    if ((sorted ?? false) && (entities.length > 1)) {
      sort(entities, filesFirst: (filesFirst ?? false), sortProc: sortProc);
    }

    if (listProc != null) {
      for (var repeatNo = 0; repeatNo < repeats; repeatNo++) {
        var entityCount = entities.length;

        if (entityCount > 0) {
          for (var entityNo = 0; entityNo < entityCount; entityNo++) {
            var subPath = entities[entityNo].path.substring(dirNameLen);

            if (!listProc(entities, entityNo, repeatNo, subPath)) {
              break;
            }
          }
        }
        else {
          listProc(entities, -1, -1, null);
        }
      }

      entities = null;
    }

    return entities;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void sort(
      List<FileSystemEntity> entities, {
      bool filesFirst = false,
      int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc
    }) {
    var pathSep = Platform.pathSeparator;

    if (sortProc != null) {
      entities.sort(sortProc);
    }
    else {
      entities.sort((e1, e2) {
        var result = 0;

        var isDir1 = (e1 is Directory);
        var isDir2 = (e2 is Directory);

        if (isDir1 == isDir2) {
          var pathComps1 = e1.path.split(pathSep);
          var pathComps2 = e2.path.split(pathSep);

          var pathCompCount1 = pathComps1.length;
          var pathCompCount2 = pathComps2.length;
          var pathCompCountMin = (pathCompCount1 < pathCompCount2
              ? pathCompCount1
              : pathCompCount2);

          for (var i = 0; (result == 0) && (i < pathCompCountMin); i++) {
            result = pathComps1[i].compareTo(pathComps2[i]);
          }

          if (result == 0) {
            result = (pathCompCount1 < pathCompCount2 ? -1 : (pathCompCount1 >
                pathCompCount2 ? 1 : 0));
          }
        }
        else if (filesFirst) {
          result = (isDir1 && !isDir2 ? 1 : -1);
        }
        else {
          result = (isDir1 && !isDir2 ? -1 : 1);
        }

        return result;
      });
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}