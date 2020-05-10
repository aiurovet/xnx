import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:doul/ext/string.dart';
import 'package:path/path.dart' as Path;

import 'ext/directory.dart';
import 'ext/file.dart';
import 'ext/glob.dart';

class FileOper {

  //////////////////////////////////////////////////////////////////////////////

  static void createDirSync({String dirName, List<String> dirNames, int start = 0,
    int end, delete = false, bool silent = false}) {

    var dirNamesEx = <String>[];

    if (dirName != null) {
      dirNamesEx.add(dirName);
    }

    var dirNameCount = (dirNames?.length ?? 0);
    var startEx = (start ?? 0);
    var endEx = (end ?? dirNameCount);

    if ((endEx > startEx) && (dirNameCount >= (endEx - startEx))) {
      dirNamesEx.addAll(dirNames.sublist(startEx, endEx));
    }

    dirNameCount = (dirNamesEx?.length ?? 0);

    if (dirNameCount <= 0) {
      return;
    }

    dirNamesEx.forEach((currDirName) {
      if (File(currDirName).existsSync()) {
        throw Exception('Can\'t create dir "${currDirName}", as this is an existing file');
      }

      if (!silent) {
        print('Creating dir "${currDirName}"');
      }

      Directory(currDirName).createSync(recursive: true);
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  static void deleteSync({String path, List<String> paths, int start = 0,
    int end, delete = false, bool silent = false}) {

    if ((path == null) && ((paths == null) || paths.isEmpty)) {
      return;
    }

    listSync(path: path, paths: paths, start: start, end: end,
      silent: silent, sorted: true, minimal: false,
      listProc: (entities, entityNo, repeatNo, subPath) {
        if (entityNo < 0) { // empty list
          if (!silent) {
            throw Exception('Source was not found: "${path ?? paths[start] ?? StringExt.EMPTY}"');
          }
        }

        var entity = entities[entityNo];

        if (entity.existsSync()) {
          entity.deleteSync(recursive: true);
        }

        return true;
      }
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> listSync({String path, List<String> paths,
    int start = 0, int end, int repeats = 1, bool sorted = true,
    bool minimal = false, bool silent = false,
    bool Function(List<FileSystemEntity> entities, int entityNo, int repeatNo, String subPath) listProc,
    int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc}) {

    // Get list of file system entities to walk through

    var pathsEx = <String>[];

    if (!StringExt.isNullOrBlank(path)) {
      pathsEx.add(path);
    }

    var pathCount = (paths?.length ?? 0);
    var startEx = (start ?? 0);
    var endEx = (end ?? pathCount);

    if ((endEx > startEx) && (pathCount >= (endEx - startEx))) {
      pathsEx.addAll(paths.sublist(startEx, endEx));
    }

    pathCount = (pathsEx?.length ?? 0);

    var dirNameLen = -1;
    var entities = <FileSystemEntity>[];

    for (var pathNo = 0; pathNo < pathCount; pathNo++) {
      var currPath = pathsEx[pathNo];
      var currDir = Directory(currPath);
      var currDirNameLen = 0;

      // If path is an existing directory, then grab all of it's children

      if (currDir.existsSync()) {
        currDirNameLen = currPath.length;

        entities.add(currDir);

        if (!(minimal ?? false)) {
          entities.addAll(currDir.listSync(recursive: true));
        }
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
            currDirName = DirectoryExt.CUR_DIR_ABBR;
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

      if ((dirNameLen < 0) || (dirNameLen > currDirNameLen)) {
        dirNameLen = currDirNameLen;
      }
    }

    if (entities.isNotEmpty) {
      if (sorted ?? false) {
        sort(entities, sortProc: sortProc);
      }
      if (minimal ?? false) {
        removeSubPaths(entities, fast: (sortProc == null));
      }
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

  static void removeSubPaths(List<FileSystemEntity> entities, {bool fast = true}) {
    var entitiesToRemove = <FileSystemEntity>[];
    var pathCount = entities.length;
    var pathSep = Platform.pathSeparator;

    for (var currPathNo = 0; currPathNo < pathCount; currPathNo++) {
      var currEntity = entities[currPathNo];

      if (entitiesToRemove.contains(currEntity)) {
        continue;
      }

      var currPath = currEntity.path;
      var startPrevPathNo = 0;
      var endPrevPathNo = (fast ? currPathNo : pathCount);

      for (var prevPathNo = startPrevPathNo; prevPathNo < endPrevPathNo; prevPathNo++) {
        if (prevPathNo == currPathNo) {
          continue;
        }

        var prevEntity = entities[prevPathNo];
        var prevPath = prevEntity.path;

        if (!prevPath.endsWith(pathSep)) {
          prevPath += pathSep;
        }

        if (currPath.contains(prevPath)) {
          entitiesToRemove.add(currEntity);
          break;
        }
      }
    }

    entities.removeWhere((entity) => entitiesToRemove.contains(entity));
  }

  //////////////////////////////////////////////////////////////////////////////

  static void sort(List<FileSystemEntity> entities,
    {int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc}) {

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

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    if (toDirName == null) {
      if (toFilePath != null) {
        File(fromPath).xferSync(toFilePath, move: move, newerOnly: newerOnly, silent: silent);
        return;
      }

      toDirName = fromPaths[end];
    }

    listSync(path: fromPath, paths: fromPaths, start: start, end: end,
      silent: silent, sorted: true, minimal: true,
      listProc: (entities, entityNo, repeatNo, subPath) {
        if (entityNo < 0) { // empty list
          if (!silent) {
            throw Exception('Source was not found: "${fromPath ?? fromPaths[start] ?? StringExt.EMPTY}"');
          }
        }

        var entity = entities[entityNo];

        if (entity is Directory) {
          entity.xferSync(Path.join(toDirName, subPath), move: move, newerOnly: newerOnly, silent: silent);
        }
        else if (entity is File) {
          entity.xferSync(toDirName, move: move, newerOnly: newerOnly, silent: silent);
        }

        return true;
      }
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static void zipSync({String fromPath, List<String> fromPaths,
    String toFilePath, int start = 0, int end,
    bool move = false, bool silent = false}) {

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    var toFile = File(toFilePath ?? fromPaths[end]);
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

    listSync(path: fromPath, paths: fromPaths, start: start, end: end,
      repeats: (move ? 2 : 1), silent: silent, sorted: true, minimal: true,
      listProc: (entities, entityNo, repeatNo, subPath) {
        if (entityNo < 0) { // empty list
          if (!silent) {
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
          if (!silent) {
            print('${move ? 'Moving' : 'Adding'} ${isDir ? 'dir ' : 'file'} "${entity.path}"');
          }

          if (isDir) {
            encoder.addDirectory(entity, includeDirName: (subPath.length > 0));
          }
          else {
            encoder.addFile(entity);
          }
        }
        else if (move && (repeatNo == 1)) {
          if (entity.existsSync()) {
            entity.deleteSync(recursive: true);
          }
        }

        return true;
      }
    );

    encoder.close();
  }

  //////////////////////////////////////////////////////////////////////////////

}