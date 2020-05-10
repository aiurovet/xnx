import 'dart:io';
import 'package:path/path.dart' as Path;
import 'file.dart';
import 'glob.dart';
import 'string.dart';

extension DirectoryExt on Directory {

  //////////////////////////////////////////////////////////////////////////////

  static final CUR_DIR_ABBR = '.';
  static final PARENT_DIR_ABBR = '..';

  //////////////////////////////////////////////////////////////////////////////

  static String appendPathSeparator(String dirName) {
    var pathSep = Platform.pathSeparator;

    if (StringExt.isNullOrEmpty(dirName) || dirName.endsWith(pathSep)) {
      return dirName;
    }
    else {
      return (dirName + pathSep);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void deleteIfExistsSync() {
    if (existsSync()) {
      deleteSync(recursive: true);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  List<FileSystemEntity> entityListSync(String pattern, {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var lst = <FileSystemEntity>[];

    if (checkExists && !existsSync()) {
      return lst;
    }

    var filter = GlobExt.toGlob(pattern);
    var entities = filter.listSync(root: path);

    for (var entity in entities) {
      if (entity is Directory) {
        if (takeDirs) {
          lst.add(entity);
        }
      }
      else if (takeFiles) {
        lst.add(entity);
      }
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> entityListExSync(String pattern, {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var dirName = GlobExt.getDirectoryName(pattern);
    var subPattern = ((dirName == null) || (dirName.length <= 1) ? pattern : pattern.substring(dirName.length + 1));
    var dir = Directory(dirName);
    var lst = dir.entityListSync(subPattern, checkExists: checkExists, takeDirs: takeDirs, takeFiles: takeFiles);

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  int getFullLevel() {
    return path.getFullPath().tokensOf(Platform.pathSeparator);
  }

  //////////////////////////////////////////////////////////////////////////////

  int getLevel() {
    return path.tokensOf(Platform.pathSeparator);
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> pathListSync(String pattern, {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var lst = <String>[];

    if (checkExists && !existsSync()) {
      return lst;
    }

    var filter = GlobExt.toGlob(pattern);
    var entities = filter.listSync(root: path);

    for (var entity in entities) {
      var entityPath = entity.path;

      if (entity is Directory) {
        if (takeDirs) {
          lst.add(entityPath);
        }
      }
      else if (takeFiles) {
        lst.add(entityPath);
      }
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> pathListExSync(String pattern, {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var dirName = GlobExt.getDirectoryName(pattern);
    var subPattern = ((dirName == null) || (dirName.length <= 1) ? pattern : pattern.substring(dirName.length + 1));
    var dir = Directory(dirName);
    var lst = dir.pathListSync(subPattern, checkExists: checkExists, takeDirs: takeDirs, takeFiles: takeFiles);

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  void xferSync(String toDirName, {bool move = false, bool newerOnly = false, bool silent = false}) {
    var fromFullDirName = appendPathSeparator(path.getFullPath());
    var toFullDirName = appendPathSeparator(toDirName.getFullPath());

    if (toFullDirName.contains(fromFullDirName)) {
      if (silent) {
        return;
      }
      else {
        var action = 'Can\'t ${move ? 'rename' : 'copy'} directory "${fromFullDirName}"';
        var target = (toFullDirName == fromFullDirName ? 'itself' : 'it\'s sub-directory ${toFullDirName}');

        throw Exception('${action} to ${target}');
      }
    }

    if (!silent) {
      print('--- ${move ? 'Renaming' : 'Copying'} dir "${path}"');
    }

    if (move) {
      Directory(Path.dirname(toDirName)).createSync();

      var toDir = Directory(toDirName);

      if (toDir.existsSync()) {
        toDir.deleteSync(recursive: true);
      }

      renameSync(toDirName);

      return;
    }

    var toDir = Directory(toDirName);
    toDir.createSync(recursive: true);

    var entities = listSync(recursive: false);

    entities.sort((e1, e2) {
      var isDir1 = (e1 is Directory);
      var isDir2 = (e2 is Directory);

      if (isDir1 == isDir2) {
        return e1.path.compareTo(e2.path);
      }
      else {
        return (isDir1 ? -1 : 1);
      }
    });

    var dirNameLen = path.length;

    for (var i = 0, n = entities.length; i < n; i++) {
      var entity = entities[i];

      if (entity is Directory) {
        var toSubDirName = toDirName + entity.path.substring(dirNameLen);

        entity.xferSync(toSubDirName, move: move, newerOnly: newerOnly, silent: silent);
      }
      else if (entity is File) {
        var toPath = Path.join(toDirName, Path.basename(entity.path));
        entity.xferSync(toPath, move: move, newerOnly: newerOnly, silent: silent);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}