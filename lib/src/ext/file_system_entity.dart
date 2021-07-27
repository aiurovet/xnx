import 'dart:io';
import 'package:doul/src/ext/glob.dart';
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

  static bool tryPatternExistsSync(String entityName, {recursive = false}) {
    try {
      var parentName = path_api.dirname(entityName);
      var filter = GlobExt.toGlob(path_api.basename(entityName));
      var lst = filter.listSync(root: parentName);
      var isFound = lst.any((x) => true);

      return isFound;
    }
    catch (e) {
      // Suppressed
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

}