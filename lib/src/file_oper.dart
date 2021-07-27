import 'dart:io';
import 'package:doul/src/ext/string.dart';
import 'package:doul/src/ext/directory.dart';
import 'package:doul/src/ext/file.dart';
import 'package:doul/src/ext/glob.dart';
import 'package:path/path.dart' as path_api;

class FileOper {

  //////////////////////////////////////////////////////////////////////////////

  static void createDirSync({String dirName, List<String> dirNames, int start = 0,
    int end, delete = false, bool isSilent = false}) {

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
        throw Exception('Can\'t create dir "$currDirName", as this is an existing file');
      }

      if (!isSilent) {
        print('Creating dir "$currDirName"');
      }

      Directory(currDirName).createSync(recursive: true);
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  static void deleteSync({String path, List<String> paths, int start = 0,
    int end, delete = false, bool isSilent = false}) {

    var pathsEx = <String>[];

    if (StringExt.isNullOrBlank(path)) {
      pathsEx = paths;
    }
    else {
      pathsEx.add(path);

      if (paths?.isNotEmpty ?? false) {
        pathsEx.addAll(paths);
      }
    }

    if (pathsEx.isNotEmpty) {
      var tmpPaths = <String>[];

      for (var currPath in paths) {
        if (Directory(currPath).existsSync() || File(currPath).existsSync()) {
          tmpPaths.add(currPath);
        }
      }

      pathsEx = tmpPaths;
    }
    else {
      return;
    }

    if (pathsEx.isEmpty) {
      return;
    }

    listSync(path: null, paths: pathsEx, start: start, end: end,
      isSilent: isSilent, isSorted: true, isMinimal: false,
      listProc: (entities, entityNo, repeatNo, subPath) {
        if (entityNo < 0) { // empty list
          throw Exception('Source was not found: "${path ?? paths[start] ?? StringExt.EMPTY}"');
        }

        var entity = entities[entityNo];

        if (entity.existsSync()) {
          if (!isSilent) {
            print('Deleting ${entity is Directory ? 'dir' : 'file'} "${entity.path}"');
          }

          entity.deleteSync(recursive: true);
        }

        return true;
      }
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> listSync({String path, List<String> paths,
    int start = 0, int end, int repeats = 1, bool isSorted = true,
    bool isMinimal = false, bool isSilent = false,
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
      var currPath = pathsEx[pathNo].adjustPath();
      var currDir = Directory(currPath);
      var currDirNameLen = 0;

      // If path is an existing directory, then grab all of it's children

      if (currDir.existsSync()) {
        currDirNameLen = currPath.length;

        entities.add(currDir);

        if (!(isMinimal ?? false)) {
          entities.addAll(currDir.listSync(recursive: true));
        }
      }
      else {
        // If path is an existing file, then the list is just a single file

        var file = File(currPath);

        if (file.existsSync()) {
          currDirNameLen = (currPath.length - path_api.basename(currPath).length);
          entities.add(file);
        }
        else {
          // If we've got here, then either path contains wildcard(s), or it
          // simply does not exist

          var currDirName = GlobExt.getDirectoryName(currPath);

          if (!StringExt.isNullOrBlank(currDirName) && (currDirName != DirectoryExt.CUR_DIR_ABBR)) {
            if (!Directory(currDirName).existsSync()) {
              throw Exception('Top source directory was not found: "${currDir.path}"');
            }
          }

          // Ensure no trailing path separator

          currDirNameLen = currDirName.length;

          if ((currDirNameLen > 0) && (currDirNameLen < currPath.length)) {
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
      if (isSorted ?? false) {
        sort(entities, sortProc: sortProc);
      }
      if (isMinimal ?? false) {
        removeSubPaths(entities, isFast: (sortProc == null));
      }

      dirNameLen -= shortenSubPaths(entities, (DirectoryExt.CUR_DIR_ABBR + StringExt.PATH_SEP));

      if (dirNameLen < 0) {
        dirNameLen = 0;
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

  static int removeSubPaths(List<FileSystemEntity> entities, {bool isFast = true}) {
    var entitiesToRemove = <FileSystemEntity>[];
    var pathCount = entities.length;

    for (var currPathNo = 0; currPathNo < pathCount; currPathNo++) {
      var currEntity = entities[currPathNo];

      if (entitiesToRemove.contains(currEntity)) {
        continue;
      }

      var currPath = currEntity.path;
      var startPrevPathNo = 0;
      var endPrevPathNo = (isFast ? currPathNo : pathCount);

      for (var prevPathNo = startPrevPathNo; prevPathNo < endPrevPathNo; prevPathNo++) {
        if (prevPathNo == currPathNo) {
          continue;
        }

        var prevEntity = entities[prevPathNo];
        var prevPath = prevEntity.path;

        if (!prevPath.endsWith(StringExt.PATH_SEP)) {
          prevPath += StringExt.PATH_SEP;
        }

        if (currPath.contains(prevPath)) {
          entitiesToRemove.add(currEntity);
          break;
        }
      }
    }

    final removedCount = entitiesToRemove.length;

    if (removedCount > 0) {
      entities.removeWhere((entity) => entitiesToRemove.contains(entity));
    }

    return removedCount;
  }

  //////////////////////////////////////////////////////////////////////////////

  static int shortenSubPaths(List<FileSystemEntity> entities, String prefix) {
    if (StringExt.isNullOrBlank(prefix)) {
      return 0;
    }

    final prefixLen = prefix.length;
    var wasShortened = false;

    for (var i = 0, n = entities.length; i < n; i++) {
      var entity = entities[i];
      final entityPath = entities[i].path;

      if (entityPath.startsWith(prefix)) {
        if (entity is Directory) {
          entity = Directory(entity.path.substring(prefixLen));
        }
        else if (entity is File) {
          entity = File(entity.path.substring(prefixLen));
        }

        entities[i] = entity;
        wasShortened = true;
      }
    }

    return (wasShortened ? prefixLen : 0);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void sort(List<FileSystemEntity> entities,
    {int Function(FileSystemEntity entity1, FileSystemEntity entity2) sortProc}) {

    if (sortProc != null) {
      entities.sort(sortProc);
    }
    else {
      entities.sort((e1, e2) {
        var result = 0;

        var isDir1 = (e1 is Directory);
        var isDir2 = (e2 is Directory);

        if (isDir1 == isDir2) {
          var pathComps1 = e1.path.split(StringExt.PATH_SEP);
          var pathComps2 = e2.path.split(StringExt.PATH_SEP);

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
    bool isMove = false, bool isNewerOnly = false, bool isSilent = false}) {

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    if (toDirName == null) {
      if (toFilePath != null) {
        File(fromPath).xferSync(toFilePath, isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
        return;
      }

      toDirName = fromPaths[end];
    }

    listSync(path: fromPath, paths: fromPaths, start: start, end: end,
      isSilent: isSilent, isSorted: true, isMinimal: true,
      listProc: (entities, entityNo, repeatNo, subPath) {
        if (entityNo < 0) { // empty list
          throw Exception('Source was not found: "${fromPath ?? fromPaths[start] ?? StringExt.EMPTY}"');
        }

        var entity = entities[entityNo];

        if (entity is Directory) {
          entity.xferSync(path_api.join(toDirName, subPath), isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
        }
        else if (entity is File) {
          entity.xferSync(toDirName, isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
        }

        return true;
      }
    );
  }

  //////////////////////////////////////////////////////////////////////////////

}