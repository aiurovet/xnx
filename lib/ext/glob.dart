import 'dart:core';
import 'dart:io';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as Path;

import 'string.dart';

extension GlobExt on Glob {

  //////////////////////////////////////////////////////////////////////////////

  static const String ALL = '*';

  static final RegExp _RE_RECURSIVE = RegExp(r'\*\*|[\*\?].*[\/\\]', caseSensitive: false);
  static final RegExp _RE_WILDCARD = RegExp(r'\*|\?|\[[^\]]*\]|\{[^\}]*\}', caseSensitive: false);
  static final RegExp _RE_PATH = RegExp(r'[\/\\]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static final _fileSystem = LocalFileSystem();

  //////////////////////////////////////////////////////////////////////////////

  static String getDirectoryName(String pattern, {bool isDirectoryName = false}) {
    if (pattern == null) {
      return pattern;
    }
    else {
      var m = _RE_WILDCARD.firstMatch(pattern);

      if (m != null) {
        if (m.start > 0) {
          var dirName = pattern.substring(0, m.start);

          if (dirName.endsWith(StringExt.PATH_SEP)) {
            dirName = dirName.substring(0, dirName.length - 1);
          }
          else if (!dirName.contains(StringExt.PATH_SEP)) {
            dirName = StringExt.EMPTY;
          }
          else {
            dirName = Path.dirname(dirName);
          }

          return dirName;
        }
        else {
          return StringExt.EMPTY;
        }
      }
      else {
        if (isDirectoryName ?? false) {
          return pattern;
        }
        else {
          return Path.dirname(pattern);
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isGlobPattern(String pattern) {
    return ((pattern != null) && _RE_WILDCARD.hasMatch(pattern));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isRecursive(String pattern) {
    return ((pattern != null) && _RE_RECURSIVE.hasMatch(pattern));
  }

  //////////////////////////////////////////////////////////////////////////////

  List<FileSystemEntity> listSync({String root, bool followLinks = true}) {
print('DBG: root: \"${root}\"');
    return listFileSystemSync(_fileSystem, root: root.adjustPath(), followLinks: followLinks);
  }

  //////////////////////////////////////////////////////////////////////////////

  static Glob toGlob(String pattern, {bool isPath}) {
    Glob filter;

    pattern = (StringExt.isNullOrBlank(pattern) ? ALL : pattern);
    isPath = (isPath ?? _RE_PATH.hasMatch(pattern));

    var caseSensitive = !StringExt.IS_WINDOWS;
    var recursive = isRecursive(pattern);

    filter = Glob(pattern, recursive: recursive, caseSensitive: caseSensitive);

    return filter;
  }

  //////////////////////////////////////////////////////////////////////////////

}