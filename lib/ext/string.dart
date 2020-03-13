import 'dart:core';

import 'dart:io';
import 'package:path/path.dart' as path;

extension StringExt on String {
  static Map<String, String> ENVIRONMENT;
  static final bool IS_WINDOWS = Platform.isWindows;

  static final RegExp BLANK = RegExp('^[\\s]*\$');

  static final String EMPTY = '';
  static final String FALSE_STR = 'false';
  static final String NEWLINE = '\n';
  static final String SPACE = ' ';
  static final String TAB = '\t';
  static final String TRUE = 'true';
  static final String FALSE = 'false';

  static final RegExp RE_ENV_NAME = RegExp('\\\$[\\{]?([A-Z_][A-Z _0-9]*)[\\}]?', caseSensitive: false);
  static final RegExp RE_IS_WILDCARD = RegExp('[\\*\\?]', caseSensitive: false);
  static final RegExp RE_PATH_SEP = RegExp('[\\/]', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp('^[a-z]+[\:][\\/][\\/]+', caseSensitive: false);

  String adjustPath() {
    var adjustedPath = trim().replaceAll(RE_PATH_SEP, Platform.pathSeparator);

    return adjustedPath;
  }

  bool containsWildcards() {
    return RE_IS_WILDCARD.hasMatch(this);
  }

  String expandEnvironmentVariables() {
    if (ENVIRONMENT == null) {
      _initEnvironmentVariables();
    }

    var result = this
        .replaceAll('\$\$', '\x01')
        .replaceAllMapped(RE_ENV_NAME, (match) {
          var envName = match.group(1);

          if (IS_WINDOWS) {
            envName = envName.toUpperCase();
          }

          if (ENVIRONMENT.containsKey(envName)) {
            return ENVIRONMENT[envName];
          }
          else {
            return EMPTY;
          }
        })
        .replaceAll('\x01', '\$');

    return result;
  }

  String getFullPath() {
    var fullPath = path.canonicalize(adjustPath());

    return fullPath;
  }

  static void _initEnvironmentVariables() {
    ENVIRONMENT = {};

    if (IS_WINDOWS) {
      Platform.environment.forEach((k, v) {
        ENVIRONMENT[k.toUpperCase()] = v;
      });
    }
    else {
      ENVIRONMENT = Map.from(Platform.environment);
    }
  }

  static bool isNullOrBlank(String input) {
    return ((input == null) || BLANK.hasMatch(input));
  }

  static bool isNullOrEmpty(String input) {
    return ((input == null) || input.isEmpty);
  }

  static bool parseBool(String input) {
    return ((input != null) && (input.toLowerCase() == TRUE));
  }

  RegExp wildcardToRegExp() {
    if (isNullOrBlank(this)) {
      return null;
    }
    else {
      var pattern = '^${RegExp.escape(this).replaceAll('\\*', '.*').replaceAll('\\?', '.')}\$';

      return RegExp(pattern, caseSensitive: !IS_WINDOWS);
    }
  }
}