import 'dart:io';
import 'package:path/path.dart' as Path;
import 'wildcard.dart';

extension DirectoryExt on Directory {

  //////////////////////////////////////////////////////////////////////////////

  List<String> pathListSync(String pattern, {bool checkExists = true, bool isRecursive, bool takeDirs = false, bool takeFiles = true}) {
    return _pathListSync(
      pattern,
      (checkExists ?? false),
      (isRecursive ?? Wildcard.isRecursive(pattern)),
      (takeDirs ?? false),
      (takeFiles ?? false)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> _pathListSync(String pattern, bool checkExists, bool isRecursive, bool takeDirs, bool takeFiles) {
    var lst = <String>[];

    if (checkExists && !existsSync()) {
      return lst;
    }

    var entities = listSync().toList();
    var filter = (pattern == null ? null : Wildcard.toRegExp(pattern));

    for (var entity in entities) {
      if (entity is Directory) {
        var entityPath = entity.path;

        if (takeDirs) {
          if ((filter == null) || filter.hasMatch(isRecursive ? entityPath : Path.basename(entityPath))) {
            lst.add(entityPath);
          }
        }
      }
    }

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