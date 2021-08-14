import 'dart:io';
import 'package:xnx/src/ext/glob.dart';
import 'package:path/path.dart' as path_api;

extension FileSystemEntityExt on FileSystemEntity {

  //////////////////////////////////////////////////////////////////////////////

  void deleteIfExistsSync({recursive = false}) {
    if (tryExistsSync()) {
      deleteSync(recursive: recursive);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool tryExistsSync({recursive = false}) {
    try {
      return existsSync();
    }
    catch (e) {
      // Suppressed
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool tryPatternExistsSync(String entityName, {bool isDirectory = false, bool isFile = false, recursive = false}) {
    try {
      var parentName = path_api.dirname(entityName);
      var filter = GlobExt.toGlob(path_api.basename(entityName));
      var lst = filter.listSync(root: parentName);
      var entity = lst?.first;

      if (entity == null) {
        return false;
      }

      isDirectory ??= false;
      isFile ??= false;

      if (!isDirectory && !isFile) {
        return true;
      }

      if (isDirectory && isFile) {
        return false;
      }

      var type = FileSystemEntity.typeSync(entity.path);

      if (isDirectory && (type == FileSystemEntityType.directory)) {
        return true;
      }
      else if (isFile && (type == FileSystemEntityType.file)) {
        return true;
      }
      else {
        return false;
      }
    }
    catch (e) {
      // Suppressed
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

}