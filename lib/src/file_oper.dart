import 'package:file/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/ext/directory.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/glob.dart';

class FileOper {
  //////////////////////////////////////////////////////////////////////////////

  static void createDirSync(List<String> dirNames, {bool isSilent = false}) {
    var dirNameLists = Path.argsToLists(dirNames, oper: 'create directory');

    dirNameLists[0].forEach((currDirName) {
      if (currDirName.isBlank() || Path.fileSystem.file(currDirName).existsSync()) {
        return;
      }

      if (!isSilent) {
        print('Creating dir "$currDirName"');
      }

      Path.fileSystem.directory(currDirName).createSync(recursive: true);
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  static void deleteSync(List<String> paths, {bool isSilent = false}) {
    var pathLists = Path.argsToLists(paths, oper: 'delete directory');

    listSync(pathLists[0], isSilent: isSilent, isSorted: true, isMinimal: false, listProc: (entities, entityNo, repeatNo, subPath) {
      if (entityNo < 0) {
        return true;
      }

      var entity = entities[entityNo];

      if (entity.existsSync()) {
        if (!isSilent) {
          print('Deleting ${entity is Directory ? 'dir' : 'file'} "${entity.path}"');
        }

        entity.deleteSync(recursive: true);
      }

      return true;
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> listSync(List<String> paths, {
      int repeats = 1, bool isSorted = true, bool isMinimal = false, bool isSilent = false,
      bool Function(List<FileSystemEntity> entities, int entityNo, int repeatNo, String? subPath)? listProc,
      int Function(FileSystemEntity entity1, FileSystemEntity entity2)? sortProc
    }) {
    // Get list of file system entities to walk through

    var pathCount = paths.length;

    var dirNameLen = -1;
    var entities = <FileSystemEntity>[];

    for (var pathNo = 0; pathNo < pathCount; pathNo++) {
      var currPath = Path.adjust(paths[pathNo]);
      var currDir = Path.fileSystem.directory(currPath);
      var currDirNameLen = 0;

      // If path is an existing directory, then grab all of it's children

      if (currDir.existsSync()) {
        currDirNameLen = currPath.length;

        entities.add(currDir);

        if (!isMinimal) {
          entities.addAll(currDir.listSync(recursive: true));
        }
      }
      else {
        // If path is an existing file, then the list is just a single file

        var file = Path.fileSystem.file(currPath);

        if (file.existsSync()) {
          currDirNameLen = (currPath.length - Path.basename(currPath).length);
          entities.add(file);
        }
        else {
          // If we've got here, then either path contains wildcard(s), or it
          // simply does not exist

          var currDirName = GlobExt.dirname(currPath);

          if (!currDirName.isBlank() &&
              (currDirName != DirectoryExt.CUR_DIR_ABBR)) {
            if (!Path.fileSystem.directory(currDirName).existsSync()) {
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
          entities.addAll(currFilter.listFileSystemSync(Path.fileSystem, root: currDirName));
        }
      }

      // Shorten common prefix if needed

      if ((dirNameLen < 0) || (dirNameLen > currDirNameLen)) {
        dirNameLen = currDirNameLen;
      }
    }

    if (entities.isNotEmpty) {
      if (isSorted && (sortProc != null)) {
        sort(entities, sortProc: sortProc);
      }
      if (isMinimal) {
        _removeSubPaths(entities, isFast: (sortProc == null));
      }

      dirNameLen -= _shortenSubPaths(entities, (DirectoryExt.CUR_DIR_ABBR + Path.separator));

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

      entities.clear();
    }

    return entities;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Internal methods
  //////////////////////////////////////////////////////////////////////////////

  static int _removeSubPaths(List<FileSystemEntity> entities, {bool isFast = true}) {
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

      for (var prevPathNo = startPrevPathNo;
          prevPathNo < endPrevPathNo;
          prevPathNo++) {
        if (prevPathNo == currPathNo) {
          continue;
        }

        var prevEntity = entities[prevPathNo];
        var prevPath = prevEntity.path;

        if (!prevPath.endsWith(Path.separator)) {
          prevPath += Path.separator;
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

  static int _shortenSubPaths(List<FileSystemEntity> entities, String prefix) {
    if (prefix.isBlank()) {
      return 0;
    }

    final prefixLen = prefix.length;
    var wasShortened = false;

    for (var i = 0, n = entities.length; i < n; i++) {
      var entity = entities[i];
      final entityPath = entities[i].path;

      if (entityPath.startsWith(prefix)) {
        if (entity is Directory) {
          entity = Path.fileSystem.directory(entity.path.substring(prefixLen));
        }
        else if (entity is File) {
          entity = Path.fileSystem.file(entity.path.substring(prefixLen));
        }

        entities[i] = entity;
        wasShortened = true;
      }
    }

    return (wasShortened ? prefixLen : 0);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void sort(List<FileSystemEntity> entities, {int Function(FileSystemEntity entity1, FileSystemEntity entity2)? sortProc}) {
    if (sortProc != null) {
      entities.sort(sortProc);
    }
    else {
      entities.sort((e1, e2) {
        var result = 0;

        var isDir1 = (e1 is Directory);
        var isDir2 = (e2 is Directory);

        if (isDir1 == isDir2) {
          var pathComps1 = e1.path.split(Path.separator);
          var pathComps2 = e2.path.split(Path.separator);

          var pathCompCount1 = pathComps1.length;
          var pathCompCount2 = pathComps2.length;
          var pathCompCountMin = (pathCompCount1 < pathCompCount2 ? pathCompCount1 : pathCompCount2);

          for (var i = 0; (result == 0) && (i < pathCompCountMin); i++) {
            result = pathComps1[i].compareTo(pathComps2[i]);
          }

          if (result == 0) {
            result = (pathCompCount1 < pathCompCount2 ? -1 : pathCompCount1 > pathCompCount2 ? 1 : 0);
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

  static void xferSync(List<String> paths, {bool isMove = false, bool isNewerOnly = false, bool isSilent = false}) {
    var pathLists = Path.argsToLists(paths, oper: (isMove ? 'move' : 'copy'), isLastSeparate: true);
    var toDirName = pathLists[1][0];

    listSync(pathLists[0], isSilent: isSilent, isSorted: true, isMinimal: true, listProc: (entities, entityNo, repeatNo, subPath) {
      if (entityNo < 0) {
        // empty list
      }

      var entity = entities[entityNo];

      if (entity is Directory) {
        entity.xferSync(Path.join(toDirName, subPath), isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
      }
      else if (entity is File) {
        entity.xferSync(toDirName, isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
      }

      return true;
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
