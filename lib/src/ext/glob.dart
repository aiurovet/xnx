import 'dart:core';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:xnx/src/ext/path.dart';
import 'string.dart';

extension GlobExt on Glob {

  //////////////////////////////////////////////////////////////////////////////

  static const String ALL = '*';

  static final RegExp _RE_RECURSIVE = RegExp(r'\*\*|[\*\?].*[\/\\]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static String dirname(String pattern, {bool isDirectoryName = false}) {
    if (pattern.isEmpty || !pattern.contains(Path.separator)) {
      if (Path.driveSeparator.isEmpty || !pattern.contains(Path.driveSeparator)) {
        return '';
      }
    }

    var dirName = '';
    var parts = Path.dirname(pattern).split(Path.separator);

    for (var part in parts) {
      if (isGlobPattern(part)) {
        break;
      }
      if (part.isEmpty) {
        dirName += Path.separator;
      }
      else {
        dirName = Path.join(dirName, part);
      }
    }

    return dirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isRecursive(String? pattern) {
    if (pattern == null) {
      return false;
    }

    final m = _RE_RECURSIVE.firstMatch(pattern);

    if ((m == null) || (m.start < 0)) {
      return false;
    }

    return (Path.adjust(pattern).contains(Path.separator, m.start + 1));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isGlobPattern(String? pattern) {
    if (pattern == null) {
      return false;
    }

    if (pattern.contains('*') ||
        pattern.contains('?') ||
        pattern.contains('{') ||
        pattern.contains('[')) {
      return true;
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<FileSystemEntity> listSync({String? root, bool? recursive, bool followLinks = false}) {
    var that = this;

    var fullRoot = (root == null ?
      Path.fileSystem.currentDirectory.path :
      Path.getFullPath(root)
    );

    var lst = Path.fileSystem
      .directory(fullRoot)
      .listSync(
        recursive: recursive ?? isRecursive(pattern),
        followLinks: followLinks
      )
      .where((x) {
        var hasMatch = that.matches(Path.toPosix(Path.relative(x.path, from: fullRoot)));
        return hasMatch;
      })
      .toList()
    ;

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  static Glob toGlob(String? pattern, {bool? isPath}) {
    var patternEx = ((pattern == null) || pattern.isBlank() ? ALL : pattern);

    var filter = Glob(
      Path.toPosix(patternEx),
      recursive: isRecursive(patternEx),
      caseSensitive: Path.isCaseSensitive
    );

    return filter;
  }

  //////////////////////////////////////////////////////////////////////////////

}