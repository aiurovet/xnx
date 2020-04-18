import 'dart:core';
import 'dart:io';
import 'package:path/path.dart' as Path;

import 'string.dart';

class Wildcard {

  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _RE_RECURSIVE = RegExp(r'\*\*|\?\?', caseSensitive: false);
  static final RegExp _RE_WILDCARD = RegExp(r'[\*\?]', caseSensitive: false);
  static final RegExp _RE_WILDCARD_DIR = RegExp(r'[\*\?]+[\/\\]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static bool isA(String pattern) {
    return ((pattern != null) && _RE_WILDCARD.hasMatch(pattern));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isRecursive(String pattern) {
    return ((pattern != null) && _RE_RECURSIVE.hasMatch(pattern));
  }

  //////////////////////////////////////////////////////////////////////////////

  static RegExp toRegExp(String pattern) {
    if (pattern == null) {
      return null;
    }

    var patternEx = pattern
      .replaceAll(_RE_WILDCARD_DIR, StringExt.EMPTY);

    patternEx = RegExp.escape(patternEx);

    patternEx = patternEx
      .replaceAll('\\*', '.*')
      .replaceAll('\\?', '.');

    return RegExp('^${patternEx}\$', caseSensitive: !StringExt.IS_WINDOWS);
  }

  //////////////////////////////////////////////////////////////////////////////

}