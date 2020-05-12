import 'dart:io';
import 'string.dart';

extension FileSystemEntityExt on FileSystemEntity {

  //////////////////////////////////////////////////////////////////////////////

  void deleteIfExistsSync({recursive = false}) {
    if (existsSync()) {
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

}