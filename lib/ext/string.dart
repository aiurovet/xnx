import 'dart:core';

extension StringExt on String {
  static final RegExp BLANK = RegExp('^[\\s]*\$');

  static final String EMPTY = '';
  static final String FALSE_STR = 'false';
  static final String NEWLINE = '\n';
  static final String SPACE = ' ';
  static final String TAB = '\t';

  static bool isNullOrBlank(String input) {
    return ((input == null) || BLANK.hasMatch(input));
  }

  static bool isNullOrEmpty(String input) {
    return ((input == null) || input.isEmpty);
  }
}