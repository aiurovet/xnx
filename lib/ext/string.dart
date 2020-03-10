import 'dart:collection';
import 'dart:core';

import 'dart:io';

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
        if ((match != null) && (match.start >= 0)) {
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
        }
      })
      .replaceAll('\x01', '\$');

    return result;
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