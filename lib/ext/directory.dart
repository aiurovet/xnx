import 'dart:io';
import 'package:path/path.dart' as Path;
import 'string.dart';

extension DirectoryExt on Directory {

  //////////////////////////////////////////////////////////////////////////////

  List<String> pathListSync({String pattern, bool checkExists, bool recursive, bool takeDirs, bool takeFiles}) {
    var lst = <String>[];

    if ((checkExists ?? false) && !(existsSync())) {
      return lst;
    }

    var entities = listSync().toList();
    var filter = (pattern == null ? null : pattern.wildcardToRegExp());

    for (var entity in entities) {
      if ((takeDirs && (entity is Directory)) || (takeFiles && (entity is File))) {
        var entityPath = entity.path;

        if ((filter == null) || filter.hasMatch(Path.basename(entityPath))) {
          lst.add(entityPath);
        }
      }
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

}