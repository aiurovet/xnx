import 'dart:io';
import 'package:collection/collection.dart';
import 'package:xnx/src/ext/glob.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';

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
    FileSystemEntity? entity;

    try {
      var fullEntityName = Path.getFullPath(entityName.unquote());
      var parentName = GlobExt.dirname(fullEntityName);
      var subPattern = Path.relative(fullEntityName, from: parentName);

      var filter = GlobExt.toGlob(subPattern);
      var lst = filter.listSync(root: parentName);

      var isAny = (isDirectory == isFile);

      entity = lst.firstWhereOrNull((x) {
        var type = x.statSync().type;

        switch (type) {
          case FileSystemEntityType.directory:
            return (isAny || isDirectory);
          case FileSystemEntityType.file:
            return (isAny || isFile);
          default:
            return false;
        }
      });
    }
    catch (e) {
      // Suppressed
    }

    return (entity != null);
  }

  //////////////////////////////////////////////////////////////////////////////

}