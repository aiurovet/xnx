import 'dart:io';
import 'package:doul/ext/string.dart';
import 'package:path/path.dart' as Path;

import 'ext/file.dart';
import 'ext/glob.dart';

class FileOper {

  //////////////////////////////////////////////////////////////////////////////

  static final CUR_DIR_ABBR = '.';

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> listSync({String path, List<String> paths,
    int start = 0, int end, int repeats = 1, bool sorted = true,
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
      pathsEx.addAll(paths.sublist((start ?? 0), (end ?? pathCount)));
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
        // If path is an existing file, then the list is just a single file

        var file = File(currPath);

        if (file.existsSync()) {
          currDirNameLen = (currPath.length - Path.basename(currPath).length);
          entities.add(file);
        }
        else {
          // If we've got here, then either path contains wildcard(s), or it
          // simply does not exist

          var currDirName = GlobExt.getDirectoryName(currPath);

          if (StringExt.isNullOrBlank(currDirName)) {
            currDirName = CUR_DIR_ABBR;
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

  static void renameSync(String fromPath, String toPath, {bool silent = false}) {
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

  static void xferSync({String fromPath, List<String> fromPaths,
    String toFilePath, String toDirName, int start = 0, int end,
    bool move = false, bool newerOnly = false, bool silent = false}) {

    if ((toDirName == null) && File(toFilePath).existsSync()) {
      File(fromPath).xferSync(toFilePath, move: move, newerOnly: newerOnly, silent: silent);
      return;
    }

    listSync(path: fromPath, paths: fromPaths, start: start, end: end,
        repeats: 2, filesFirst: true, silent: silent,
        listProc: (entities, entityNo, repeatNo, subPath) {
          if (entityNo < 0) { // empty list
            if (!silent) {
              throw Exception('Source was not found: "${fromPath}"');
            }
          }

          var entity = entities[entityNo];

          if (repeatNo == 0) {
            if (entity is Directory) {

            }
          }
          else {

          }

//      if (entity is File) {
//        if ((!move && (repeatNo == 0)) || (move && (repeatNo == 1))) {
//          var fromPathEx = entity.path;
//          var toDirNameEx = Path.join(toDirName, Path.dirname(subPath));
//          var toPathEx = Path.join(toDirNameEx, Path.basename(fromPathEx));
//
//          copyFileSync(fromPathEx, toPathEx, move: move, newerOnly: newerOnly);
//        }
//      }
//      else if (entity is Directory) {
//        if (repeatNo == 1) {
//          var toDirNameEx = Path.join(toDirName, subPath);
//          createDirSync(toDirNameEx);
//        }
//      }

          return true;
        });
  }

  //////////////////////////////////////////////////////////////////////////////

}