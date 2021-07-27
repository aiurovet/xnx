import 'dart:core';
import 'dart:io';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path_api;

import 'file_system_entity.dart';
import 'string.dart';

extension GlobExt on Glob {

  //////////////////////////////////////////////////////////////////////////////

  static const String ALL = '*';

  static final RegExp _RE_GLOB = RegExp(r'\*|\?|\[[^\]]*\]|\{[^\}]*\}', caseSensitive: false);
  static final RegExp _RE_PATH = RegExp(r'[\/\\]', caseSensitive: false);
  static final RegExp _RE_RECURSIVE = RegExp(r'\*\*|[\*\?].*[\/\\]', caseSensitive: false);
  static final RegExp _RE_WILDCARD = RegExp(r'[\*\?]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static final _fileSystem = LocalFileSystem();

  //////////////////////////////////////////////////////////////////////////////

  static String getDirectoryName(String pattern, {bool isDirectoryName = false}) {
    if (pattern == null) {
      return pattern;
    }
    else {
      var m = _RE_GLOB.firstMatch(pattern);

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
            dirName = path_api.dirname(dirName);
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
          return path_api.dirname(pattern);
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isRecursive(String pattern) {
    return ((pattern != null) && _RE_RECURSIVE.hasMatch(pattern));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isGlobPattern(String pattern) {
    if (pattern == null) {
      return false;
    }

    if (_RE_WILDCARD.hasMatch(pattern)) {
      return true;
    }

    if (!_RE_GLOB.hasMatch(pattern)) {
      return false;
    }

    if (File(pattern).tryExistsSync()) {
      return false;
    }

    if (Directory(pattern).tryExistsSync()) {
      return false;
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<FileSystemEntity> listSync({String root, bool followLinks = true}) {
    var lst = listFileSystemSync(_fileSystem, root: root, followLinks: followLinks);

    return lst;
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