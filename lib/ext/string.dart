import 'dart:core';

import 'dart:io';
import 'package:path/path.dart' as Path;

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
  static final RegExp RE_PATH_SEP = RegExp('[\\/]', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp('^[a-z]+[\:][\\/][\\/]+', caseSensitive: false);

  static String adjustPath(String path) {
    var adjustedPath = (path?.trim() ?? StringExt.EMPTY).replaceAll(RE_PATH_SEP, Platform.pathSeparator);

    return adjustedPath;
  }

  static String expandEnvironmentVariables(String input) {
    if (input == null) {
      return input;
    }

    if (ENVIRONMENT == null) {
      initEnvironmentVariables();
    }

    var result = input
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

  static String getFullPath(String path) {
    var isBlank = StringExt.isNullOrBlank(path);
    var full = Path.canonicalize(isBlank ? StringExt.EMPTY : StringExt.adjustPath(path));

    return full;
  }

  static void initEnvironmentVariables() {
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
}