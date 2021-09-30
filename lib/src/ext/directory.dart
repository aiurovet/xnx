import 'package:file/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'file.dart';
import 'file_system_entity.dart';
import 'glob.dart';
import 'string.dart';

extension DirectoryExt on Directory {
  //////////////////////////////////////////////////////////////////////////////

  static final CUR_DIR_ABBR = '.';
  static final PARENT_DIR_ABBR = '..';

  //////////////////////////////////////////////////////////////////////////////

  static String appendPathSeparator(String dirName) {
    var pathSep = Path.separator;

    if (dirName.isBlank() || dirName.endsWith(pathSep)) {
      return dirName;
    }
    else {
      return (dirName + pathSep);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  List<FileSystemEntity> entityListSync(String pattern,
      {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var entities = <FileSystemEntity>[];

    if (checkExists && !tryExistsSync()) {
      return entities;
    }

    if (pattern.isBlank()) {
      entities.addAll(listSync());
    }
    else {
      var filter = GlobExt.toGlob(pattern);
      entities = filter.listSync(root: path);
    }

    var lst = <FileSystemEntity>[];

    for (var entity in entities) {
      if (entity is Directory) {
        if (takeDirs) {
          lst.add(entity);
        }
      } else if (takeFiles) {
        lst.add(entity);
      }
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<FileSystemEntity> entityListExSync(String pattern,
      {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var isDir = Path.fileSystem.isDirectorySync(pattern);

    var dirName = (isDir ? pattern : GlobExt.dirname(pattern));

    var subPattern = (isDir
      ? ''
      : (dirName.length <= 1
        ? pattern
        : pattern.substring(dirName.length + 1)));

    var dir = Path.fileSystem.directory(dirName);

    var lst = dir.entityListSync(
      subPattern,
      checkExists: checkExists,
      takeDirs: takeDirs,
      takeFiles: takeFiles
    );

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> pathListSync(String? pattern,
      {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var lst = <String>[];

    if (checkExists && !tryExistsSync()) {
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
      } else if (takeFiles) {
        lst.add(entityPath);
      }
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> pathListExSync(String pattern,
      {bool checkExists = true, bool takeDirs = false, bool takeFiles = true}) {
    var isGlobPattern = GlobExt.isGlobPattern(pattern);
    var dir = (isGlobPattern ? null : Path.fileSystem.directory(pattern));
    List<String> lst;

    if ((dir != null) && dir.existsSync()) {
      lst = dir.pathListSync(null,
          checkExists: false, takeDirs: takeDirs, takeFiles: takeFiles);
    } else if (isGlobPattern) {
      var dirName = GlobExt.dirname(pattern);
      var subPattern = (dirName.length <= 1
          ? pattern
          : pattern.substring(dirName.length + 1));

      dir = (dirName.isBlank()
          ? Path.fileSystem.currentDirectory
          : Path.fileSystem.directory(dirName));
      lst = dir.pathListSync(subPattern,
          checkExists: checkExists, takeDirs: takeDirs, takeFiles: takeFiles);
    }
    else {
      lst = [pattern];
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  void xferSync(String toDirName,
      {bool isMove = false, bool isNewerOnly = false, bool isSilent = false}) {
    var fromFullDirName = appendPathSeparator(Path.getFullPath(path));
    var toFullDirName = appendPathSeparator(Path.getFullPath(toDirName));

    if (toFullDirName.contains(fromFullDirName)) {
      var action =
          'Can\'t ${isMove ? 'rename' : 'copy'} directory "$fromFullDirName"';
      var target = (toFullDirName == fromFullDirName
          ? 'itself'
          : 'it\'s sub-directory $toFullDirName');

      throw Exception('$action to $target');
    }

    if (!isSilent) {
      print('--- ${isMove ? 'Renaming' : 'Copying'} dir "$path"');
    }

    if (isMove) {
      Path.fileSystem.directory(Path.dirname(toDirName)).createSync();

      var toDir = Path.fileSystem.directory(toDirName);

      toDir.deleteIfExistsSync(recursive: true);

      renameSync(toDirName);

      return;
    }

    var toDir = Path.fileSystem.directory(toDirName);
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

        entity.xferSync(toSubDirName,
            isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
      }
      else if (entity is File) {
        var toPath = Path.join(toDirName, Path.basename(entity.path));
        entity.xferSync(toPath,
            isMove: isMove, isNewerOnly: isNewerOnly, isSilent: isSilent);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}
