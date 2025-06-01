import 'dart:core';

import 'package:xnx/ext/env.dart';

extension StringExt on String {
  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String apos = "'";
  static const int eotCode = 4;
  static final String eot = String.fromCharCode(StringExt.eotCode);
  static const String newLine = '\n';
  static const String quot = '"';

  static const String stdinDisplay = '<stdin>';
  static const String stdinPath = '-';

  static const String stdoutDisplay = '<stdout>';
  static const String stdoutPath = StringExt.stdinPath;

  static const String unknown = '<unknown>';

  static final RegExp rexBlank = RegExp(r'^[\s]*$');

  // Taken from https://stackoverflow.com/questions/24518020/comprehensive-regexp-to-remove-javascript-comments/24518413#24518413
  static final RegExp rexComments = RegExp(
      r"""/((["'])(?:\\[\s\S]|.)*?\2|(?:[^\w\s]|^)\s*\/(?![*\/])(?:\\.|\[(?:\\.|.)\]|.)*?\/(?=[gmiy]{0,4}\s*(?![*\/])(?:\W|$)))|\/\/.*?$|\/\*[\s\S]*?\*\/""",
      multiLine: true);

  static final RegExp rexCmdLine = RegExp(
      r"""(([^\"\'\s]+)|([\"]([^\"]*)[\"])+|([\']([^\']*)[\']))+""",
      caseSensitive: false);
  static final RegExp rexInteger = RegExp(r'^\d+$', caseSensitive: false);
  static final RegExp rexProtocol =
      RegExp(r'^[A-Z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  bool isBlank() => trim().isEmpty; // faster than regex

  //////////////////////////////////////////////////////////////////////////////

  bool parseBool() => (toLowerCase() == 'true');

  String removeComments() => replaceAll(rexComments, r'$1');

  //////////////////////////////////////////////////////////////////////////////

  String quote() {
    if (!contains(' ') && !contains('\t')) {
      return this;
    }

    var q = (contains(StringExt.quot) ? StringExt.apos : StringExt.quot);

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
    var isQuoted = (((q == StringExt.apos) || (q == StringExt.quot)) &&
        (q == this[len - 1]));

    var result = (isQuoted ? substring(1, (len - 1)) : this);

    if (!result.contains(Env.escape)) {
      return result;
    }

    return result
        .replaceAll(Env.escapeEscape, '\x01')
        .replaceAll(Env.escapeApos, StringExt.apos)
        .replaceAll(Env.escapeQuot, StringExt.quot)
        .replaceAll(Env.escape, '')
        .replaceAll('\x01', Env.escape);
  }

  //////////////////////////////////////////////////////////////////////////////
}
