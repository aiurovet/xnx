import 'dart:core';
import 'dart:io';
import 'package:path/path.dart' as Path;

import 'string.dart';

class Wildcard {

  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _RE_RECURSIVE = RegExp(r'[\*][\/\\]', caseSensitive: false);
  static final RegExp _RE_WILDCARD = RegExp(r'[\*\?]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static String getStartDirName(String input, {bool isFilePattern}) {
    var dirName = input;
    
    if (input == null) {
      return dirName;
    }

    if (isFilePattern ?? File(input).existsSync()) {
      dirName = Path.dirname(input);
    }

    var match = _RE_WILDCARD.firstMatch(dirName);
    var start = (match?.start ?? -1);
    
    if (start > 0) {
      dirName = Path.dirname(dirName.substring(0, (start - 1)));
    }

    return dirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isA(String input) {
    return ((input != null) && _RE_WILDCARD.hasMatch(input));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isRecursive(String input) {
    return ((input != null) && _RE_RECURSIVE.hasMatch(input));
  }

  //////////////////////////////////////////////////////////////////////////////

  static RegExp toRegExp(String input) {
    if (input == null) {
      return null;
    }

    var pattern =
      (StringExt.RE_PATH_SEP.hasMatch(input) ? StringExt.EMPTY : '^') +
      RegExp.escape(input).replaceAll(r'\*', '.*').replaceAll(r'\?', '.') +
      '\$'
    ;

    return RegExp(pattern, caseSensitive: !StringExt.IS_WINDOWS);
  }

  //////////////////////////////////////////////////////////////////////////////

}