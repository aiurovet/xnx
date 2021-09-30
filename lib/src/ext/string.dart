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
  // static final RegExp RE_JSON_COMMAS = RegExp(r'(\"[^\"]*\")|[,][\s\x01]*([\}\]])', multiLine: false);
  // static final RegExp RE_JSON_COMMENTS = RegExp(r'(\"[^\"]*\")|\/\/[^\x01]*\x01|\/\*((?!\*\/).)*\*\/', multiLine: false);
  static final RegExp RE_INTEGER = RegExp(r'^\d+$', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp(r'^[A-Z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  bool isBlank() =>
    trim().isEmpty; // faster than regex

  //////////////////////////////////////////////////////////////////////////////

  // static bool isNullOrBlank(String? input) =>
  //   ((input == null) || RE_BLANK.hasMatch(input));

  //////////////////////////////////////////////////////////////////////////////

  static bool parseBool(String? input) =>
    ((input != null) && (input.toLowerCase() == TRUE));

  //////////////////////////////////////////////////////////////////////////////

  // String purifyJson() {
  //   var result = replaceAll('\r\n', '\x01');
  //   result = result.replaceAll('\r',   '\x01');
  //   result = result.replaceAll('\n',   '\x01');
  //   result = result.replaceAll('\\\\', '\x02');
  //   result = result.replaceAll('\\\"', '\x03');
  //   result = result.replaceAllMapped(RE_JSON_COMMENTS, (match) {
  //      var literal = match.group(1);
  //      if ((literal != null) && !literal.isBlank()) {
  //        return literal;
  //      }
  //      return EMPTY;
  //   });
  //   result = result.replaceAllMapped(RE_JSON_COMMAS, (match) {
  //     var literal = match.group(1);
  //     if ((literal != null) && !literal.isBlank()) {
  //       return literal;
  //     }
  //     return match.group(2) ?? EMPTY;
  //   });
  //   result = result.replaceAll('\x03', '\\\"');
  //   result = result.replaceAll('\x02', '\\\\');
  //   result = result.replaceAll('\x01', '\n');
  //
  //   return result;
  // }

  //////////////////////////////////////////////////////////////////////////////

  Map<int, List<String>> splitCommandLine() {
    String? cmd;
    var args = <String>[];

    var result = replaceAll(Env.escape + Env.escape, '\x01');
    result = result.replaceAll(Env.escape + "'", '\x02');
    result = result.replaceAll(Env.escape + '"', '\x03');
    result = result.replaceAllMapped(RE_CMD_LINE, (match) {
      var s = match.group(2) ?? '';

      if (s.isBlank()) {
        s = match.group(4) ?? '';

        if (s.isBlank()) {
          s = match.group(6) ?? '';
        }

        if (s.isBlank()) {
          return s;
        }
      }

      s = s.trim();

      if (cmd == null) {
        cmd = s;
      }
      else {
        args.add(s);
      }

      return s;
    });

    return <int, List<String>>{ 0: [ cmd ?? this ], 1: args };
  }

  //////////////////////////////////////////////////////////////////////////////

  String quote() {
    if (!contains(' ') && !contains('\t')) {
      return this;
    }

    var q = (contains('"') ? "'" : '"');
    var result = this;

    if (Env.escape.isNotEmpty && contains(q)) {
      result = replaceAll(Env.escape, Env.escapeEscape);
      result = result.replaceAll(q, Env.escape + q);
    }

    return q + result + q;
  }

  //////////////////////////////////////////////////////////////////////////////

  String unquote() {
    var len = length;

    if (len <= 1) {
      return this;
    }

    var q = this[0];
    var hasQ = (((q == "'") || (q == '"')) && (q == this[len - 1]));
    var result = (hasQ ? substring(1, (len - 1)) : this);

    if (result.contains(Env.escape)) {
      result = result.replaceAll(Env.escape + "'", "'");
      result = result.replaceAll(Env.escape + '"', '"');
      result = result.replaceAll(Env.escapeEscape, Env.escape);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}