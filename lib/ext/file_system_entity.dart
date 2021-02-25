import 'dart:io';
import 'package:doul/ext/glob.dart';
import 'package:path/path.dart' as Path;

import 'package:doul/ext/string.dart';

extension FileSystemEntityExt on FileSystemEntity {

  //////////////////////////////////////////////////////////////////////////////

  void deleteIfExistsSync({recursive = false}) {
    if (tryExistsSync()) {
      deleteSync(recursive: recursive);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isSamePath(String toPath) {
    var pathEx = (StringExt.IS_WINDOWS ? path.toUpperCase() : path).getFullPath();
    var toPathEx = (StringExt.IS_WINDOWS ? toPath.toUpperCase() : toPath).getFullPath();

    return (pathEx.compareTo(toPathEx) == 0);
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