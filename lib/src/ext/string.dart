import 'dart:core';

import 'package:xnx/src/ext/env.dart';

extension StringExt on String {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const int EOT_CODE = 4;
  static final String EOT = String.fromCharCode(StringExt.EOT_CODE);
  static const String FALSE_STR = 'false';
  static const String NEWLINE = '\n';
  static const String TRUE = 'true';
  static const String FALSE = 'false';

  static const String STDIN_DISPLAY = '<stdin>';
  static const String STDIN_PATH = '-';

  static const String STDOUT_DISPLAY = '<stdout>';
  static const String STDOUT_PATH = StringExt.STDIN_PATH;

  static const String UNKNOWN = '<unknown>';

  static final RegExp RE_BLANK = RegExp(r'^[\s]*$');
  static final RegExp RE_CMD_LINE = RegExp(r"""(([^\"\'\s]+)|([\"]([^\"]*)[\"])+|([\']([^\']*)[\']))+""", caseSensitive: false);
  static final RegExp RE_INTEGER = RegExp(r'^\d+$', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp(r'^[A-Z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  bool isBlank() =>
    trim().isEmpty; // faster than regex

  //////////////////////////////////////////////////////////////////////////////

  static bool parseBool(String? input) =>
    ((input != null) && (input.toLowerCase() == TRUE));

  //////////////////////////////////////////////////////////////////////////////

  String quote() {
    if (!contains(' ') && !contains('\t')) {
      return this;
    }

    var q = (contains('"') ? "'" : '"');

    return q + this + q;

    // var result = this;

    // if (Env.escape.isNotEmpty && contains(q)) {
    //   result = replaceAll(Env.escape, Env.escapeEscape);
    //   result = result.replaceAll(q, Env.escape + q);
    // }

    // return q + result + q;
  }

  //////////////////////////////////////////////////////////////////////////////

  String unquote() {
    var len = length;

    if (len <= 1) {
      return this;
    }

    var q = this[0];
    var hasQ = (((q == "'") || (q == '"')) && (q == this[len - 1]));

    return (hasQ ? substring(1, (len - 1)) : this);

    // var result = (hasQ ? substring(1, (len - 1)) : this);

    // if (result.contains(Env.escape)) {
    //   result = result.replaceAll(Env.escape + "'", "'");
    //   result = result.replaceAll(Env.escape + '"', '"');
    //   result = result.replaceAll(Env.escapeEscape, Env.escape);
    // }

    // return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}