import 'dart:io';
import 'package:doul/ext/string.dart';
import 'package:path/path.dart' as Path;

import 'ext/glob.dart';

class FileOper {

  //////////////////////////////////////////////////////////////////////////////

  static final CUR_DIR = '.';

  //////////////////////////////////////////////////////////////////////////////

  static void copySync({String fromPath, List<String> fromPaths,
    String toFilePath, String toDirName, int skip = 0, int take,
    bool newerOnly = false, bool silent = false}) {

    if ((toDirName == null) && File(toFilePath).existsSync()) {
      copyFileSync(fromPath, toFilePath, newerOnly: newerOnly, silent: silent);
      return;
    }

    listSync(path: fromPath, paths: fromPaths, skip: skip, take: take,
             repeats: 2, filesFirst: true, silent: silent,
             listProc: (entities, entityNo, repeatNo, subPath) {
      if (entityNo < 0) { // empty list
        if (!silent) {
          throw Exception('Source was not found: "${fromPath}"');
        }
      }

      var entity = entities[entityNo];

      if (entity is File) {
        if (repeatNo == 0) {
          var fromPathEx = entity.path;
          var toDirNameEx = Path.join(toDirName, Path.dirname(subPath));
          var toPathEx = Path.join(toDirNameEx, Path.basename(fromPathEx));

          copyFileSync(fromPathEx, toPathEx, newerOnly: newerOnly);
        }
      }
      else if (entity is Directory) {
        if (repeatNo == 1) {
          var toDirNameEx = Path.join(toDirName, subPath);
          createDirectorySync(toDirNameEx);
        }
      }
  
      return true;
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  static void copyFileSync(String fromPath, String toPath,
    {bool move = false, bool newerOnly = false, bool silent = false}) {

    // Ensuring source file exists

    var fromFile = File(fromPath);
    var fromStat = fromFile.statSync();

    if (fromStat.type == FileSystemEntityType.notFound) {
      if (!silent) {
        throw Exception('Copy failed, as source file was not found: "${fromFile.path}"');
      }
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

  static void moveSync({String fromPath, List<String> fromPaths,
    int skip = 0, int take, String toFilePath, String toDirName,
    bool move = false, bool newerOnly = false, bool silent = false}) {

    if ((toDirName == null) && File(toFilePath).existsSync()) {
      copyFileSync(fromPath, toFilePath, move: true, newerOnly: newerOnly);
      return;
    }

    listSync(path: fromPath, paths: fromPaths, skip: skip, take: take,
             repeats: 2, filesFirst: true, silent: false, listProc:
             (entities, entityNo, repeatNo, subPath) {
      if (entityNo < 0) { // empty list
        if (!silent) {
          throw Exception('Source was not found: "${fromPath}"');
        }
      }

      var entity = entities[entityNo];

      if (entity is Directory) {
        if (repeatNo == 0) {
          entity.renameSync(Path.join(toDirName, subPath));
        }
      }
      else if (entity is File) {
        if (repeatNo == 1) {
          var fromPathEx = entity.path;
          var toDirNameEx = Path.join(toDirName, Path.dirname(subPath));
          var toPathEx = Path.join(toDirNameEx, Path.basename(fromPathEx));

          copyFileSync(fromPathEx, toPathEx, move: true, newerOnly: newerOnly, silent: silent);
        }
      }

      return true;
    });
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

  static List<FileSystemEntity> listSync({String path, List<String> paths,
    int skip = 0, int take, int repeats = 1, bool sorted = true,
    bool filesFirst = false, bool silent = false,
    bool Function(List<FileSystemEntity> entities, int entityNo, int repeatNo, String subPath) listProc,
    int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc}) {

    // Get list of file system entities to walk through

    var pathsEx = <String>[];

    if (!StringExt.isNullOrBlank(path)) {
      pathsEx.add(path);
    }

    var pathCount = (paths?.length ?? 0);

    if (pathCount > 0) {
      pathsEx.addAll(paths.sublist((skip ?? 0), (take ?? pathCount)));
    }

    var dirNameLen = 0;
    var entities = <FileSystemEntity>[];

    for (var pathNo = 0; pathNo < pathCount; pathNo++) {
      var currPath = pathsEx[pathNo];
      var currDir = Directory(currPath);
      var currDirNameLen = 0;

      // If path is an existing directory, then grab all of it's children

      if (currDir.existsSync()) {
        currDirNameLen = currPath.length;
        entities.addAll(currDir.listSync(recursive: true));
      }
      else {
        var file = File(currPath);

        // If path is an existing file, then the list is just a single file

        if (file.existsSync()) {
          currDirNameLen = (currPath.length - Path.basename(currPath).length);
          entities.add(file);
        }
        else {
          // If we've got here, then either path contains wildcard(s), or it
          // simply does not exist

          var currDirName = GlobExt.getDirectoryName(currPath);

          if (StringExt.isNullOrBlank(currDirName)) {
            currDirName = CUR_DIR;
            currPath = Path.join(currDirName, currPath);
          }

          var currDir = Directory(currDirName);

          // If source directory does not exist, ensure the parent directory exists

          if (!currDir.existsSync()) {
            if (silent ?? false) {
              return null;
            }
            else {
              throw Exception('Top source directory was not found: "${currDir.path}"');
            }
          }

          // Ensure no trailing path separator

          currDirNameLen = currDirName.length;

          if (currDirNameLen < currPath.length) {
            ++currDirNameLen;
          }

          // Get the list of all files and directories matching path pattern

          var currFilter = GlobExt.toGlob(currPath.substring(currDirNameLen));
          entities.addAll(currFilter.listSync(root: currDirName));
        }
      }

      // Shorten common prefix if needed

      if (dirNameLen > currDirNameLen) {
        dirNameLen = currDirNameLen;
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

  static void sort(List<FileSystemEntity> entities, {bool filesFirst = false, int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc}) {
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
          var pathCompCountMin = (pathCompCount1 < pathCompCount2 ? pathCompCount1 : pathCompCount2);

          for (var i = 0; (result == 0) && (i < pathCompCountMin); i++) {
            result = pathComps1[i].compareTo(pathComps2[i]);
          }

          if (result == 0) {
            result = (pathCompCount1 < pathCompCount2 ? -1 :
                      pathCompCount1 > pathCompCount2 ? 1 : 0);
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