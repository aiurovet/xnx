import 'dart:io';
import 'package:path/path.dart' as Path;
import 'wildcard.dart';

extension DirectoryExt on Directory {

  //////////////////////////////////////////////////////////////////////////////

  List<String> pathListSync(String pattern, {bool checkExists = true, bool isRecursive, bool takeDirs = false, bool takeFiles = true}) {
    return pathListByRegExpSync(
      Wildcard.toRegExp(pattern),
      checkExists: (checkExists ?? false),
      isRecursive: (isRecursive ?? Wildcard.isRecursive(pattern)),
      takeDirs: (takeDirs ?? false),
      takeFiles: (takeFiles ?? false)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> pathListByRegExpSync(RegExp filter, {bool checkExists = true, bool isRecursive, bool takeDirs = false, bool takeFiles = true}) {
    var lst = <String>[];

    if (checkExists && !existsSync()) {
      return lst;
    }

    var entities = listSync().toList();

    for (var entity in entities) {
      var entityPath = entity.path;
      var hasMatch = (filter?.hasMatch(Path.basename(entityPath)) ?? true);

      if (entity is Directory) {
        if (takeDirs && hasMatch) {
          lst.add(entityPath);
        }
        if (isRecursive) {
          lst.addAll(entity.pathListByRegExpSync(filter, checkExists: false, isRecursive: true, takeDirs: takeDirs, takeFiles: takeFiles));
        }
      }
      else if (takeFiles && hasMatch) {
        lst.add(entityPath);
      }
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

}