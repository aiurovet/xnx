import 'dart:io';
import 'package:doul/ext/glob.dart';
import 'package:path/path.dart' as Path;

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
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool tryPatternExistsSync(String entityName, {recursive = false}) {
    try {
      var parentName = Path.dirname(entityName);
      var filter = GlobExt.toGlob(Path.basename(entityName));
      var lst = filter.listSync(root: parentName);
      var isFound = lst.any((x) => true);

      return isFound;
    }
    catch (e) {
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

}