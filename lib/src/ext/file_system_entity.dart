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
    FileSystemEntity entity;

    try {
      var parentName = path_api.dirname(entityName);
      var filter = GlobExt.toGlob(path_api.basename(entityName));
      var lst = filter.listSync(root: parentName);

      var isAny = ((isDirectory == null) && (isFile == null));

      entity = lst?.firstWhere((x) {
        var type = x.statSync()?.type;

        if (type == null) {
          return false;
        }

        switch (type) {
          case FileSystemEntityType.directory:
            return (isAny || isDirectory);
          case FileSystemEntityType.file:
            return (isAny || isFile);
          default:
            return false;
        }
      }, orElse: () => null);
    }
    catch (e) {
      // Suppressed
    }

    return (entity != null);
  }

  //////////////////////////////////////////////////////////////////////////////

}