import 'dart:io';
import 'glob.dart';

extension DirectoryExt on Directory {

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

}