import 'dart:io';
import 'package:doul/ext/glob.dart';
// ignore: library_prefixes
import 'package:path/path.dart' as pathx;

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
      var parentName = pathx.dirname(entityName);
      var filter = GlobExt.toGlob(pathx.basename(entityName));
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