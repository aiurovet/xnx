import 'dart:core';
import 'dart:io';
import 'package:path/path.dart' as Path;

extension StringExt on String {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> ENVIRONMENT;

  static final bool IS_WINDOWS = Platform.isWindows;
  static final String PATH_SEP = Platform.pathSeparator;

  static final RegExp BLANK = RegExp(r'^[\s]*$');

  static const String EMPTY = '';
  static const int EOT_CODE = 4;
  static final String EOT = String.fromCharCode(StringExt.EOT_CODE);
  static const String FALSE_STR = 'false';
  static const String NEWLINE = '\n';
  static const String PATH_SEP_NIX = r'/';
  static const String PATH_SEP_WIN = r'\';
  static const String QUOTE_1 = "'";
  static const String QUOTE_2 = '"';
  static const String SPACE = ' ';
  static const String TAB = '\t';
  static const String TRUE = 'true';
  static const String FALSE = 'false';

  static final String ESC = r'\'; // must be portable
  static final String ESC_ESC = (ESC + ESC);
  static final String ESC_PATH_SEP_WIN = (ESC + PATH_SEP_WIN);
  static final String ESC_QUOTE_1 = (ESC + QUOTE_1);
  static final String ESC_QUOTE_2 = (ESC + QUOTE_2);

  static const String STDIN_DISP = '<stdin>';
  static const String STDIN_PATH = '-';

  static const String STDOUT_DISP = '<stdout>';
  static const String STDOUT_PATH = StringExt.STDIN_PATH;

  static final RegExp RE_CMD_LINE = RegExp(r"""(([^\"\'\s]+)|([\"]([^\"]*)[\"])+|([\']([^\']*)[\']))+""", caseSensitive: false);
  static final RegExp RE_ENV_VAR_NAME = RegExp(r'\$([A-Z_][A-Z_0-9]*)|\$[\{]([A-Z_][A-Z_0-9]*)[\}]', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp(r'^[A-Z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  String adjustPath() => trim().replaceAll((IS_WINDOWS ? PATH_SEP_WIN : PATH_SEP_NIX), Path.separator);

  //////////////////////////////////////////////////////////////////////////////

  String escapeEscapeChar() => replaceAll(ESC, ESC_ESC);

  //////////////////////////////////////////////////////////////////////////////

  String expandEnvironmentVariables({List<String> args, bool canEscape = false}) {
    if (ENVIRONMENT == null) {
      initEnvironmentVariables();
    }

    var argCount = (args?.length ?? 0);

    var result =
       replaceAll(r'\\', '\x01')
      .replaceAll(r'\$', '\x02')
      .replaceAll(r'$$', '\x03')
      .replaceAllMapped(RE_ENV_VAR_NAME, (match) {
        var envVarName = (match.group(1) ?? match.group(2));

        if (argCount >= 0) {
          var argNo = int.tryParse(envVarName, radix: 10);

          if ((argNo ?? -1) > 0) {
            return args[argNo - 1];
          }
        }

        if (IS_WINDOWS) {
          envVarName = envVarName.toUpperCase();
        }

        if (ENVIRONMENT.containsKey(envVarName)) {
          var envExp = ENVIRONMENT[envVarName];

          return (canEscape ? envExp.escapeEscapeChar() : envExp);
        }
        else {
          return EMPTY;
        }
      })
      .replaceAll('\x03', r'$')
      .replaceAll('\x02', r'\$')
      .replaceAll('\x01', r'\\')
    ;

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getFullPath() {
    var fullPath = (this == STDIN_PATH ? this : Path.canonicalize(adjustPath()));

    return fullPath;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void initEnvironmentVariables() {
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

  //////////////////////////////////////////////////////////////////////////////

  static bool isNullOrBlank(String input) {
    return ((input == null) || BLANK.hasMatch(input));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isNullOrEmpty(String input) {
    return ((input == null) || input.isEmpty);
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool parseBool(String input) {
    return ((input != null) && (input.toLowerCase() == TRUE));
  }

  //////////////////////////////////////////////////////////////////////////////
  // N.B. Single quotes are not supported by JSON standard, only double quotes
  //////////////////////////////////////////////////////////////////////////////

  String removeJsComments() {
    var jsCommentsRE = RegExp(r'(\"[^\"]*\")|\/\/[^\x01]*\x01|\/\*((?!\*\/).)*\*\/', multiLine: false);

    var result =
      replaceAll('\r\n', '\x01')
     .replaceAll('\r',   '\x01')
     .replaceAll('\n',   '\x01')
     .replaceAll('\\\\', '\x02')
     .replaceAll('\\\"', '\x03')
     .replaceAllMapped(jsCommentsRE, (Match match) {
       var literalString = match.group(1);
       var isCommented = isNullOrBlank(literalString);

       return (isCommented ? EMPTY : literalString);
     })
     .replaceAll('\x03', '\\\"')
     .replaceAll('\x02', '\\\\')
     .replaceAll('\x01', '\n')
    ;

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> splitCommandLine({int skipCharCount = 0}) {
    var line = ((skipCharCount ?? 0) == 0 ? this : substring(skipCharCount));
    var args = <String>[];

    line.replaceAll(ESC_ESC, '\x01')
        .replaceAll(ESC_QUOTE_1, '\x02')
        .replaceAll(ESC_QUOTE_2, '\x03')
        .replaceAllMapped(RE_CMD_LINE, (match) {
          var s = match.group(2);

          if (StringExt.isNullOrBlank(s)) {
            s = match.group(4);

            if (StringExt.isNullOrBlank(s)) {
              s = match.group(6);
            }
          }

          args.add(s.trim());

          return s;
        })
    ;

    return args;
  }

  //////////////////////////////////////////////////////////////////////////////

  int tokensOf(String that) {
    var thisLen = length;
    var thatLen = (that?.length ?? 0);

    if ((thatLen <= 0) || (thatLen > thisLen)) {
      return 0;
    }
    else if (thatLen > 1) {
      return (((thisLen - replaceAll(that, EMPTY).length) / thatLen) as int);
    }
    else {
      var tokCount = 0;
      var thatChar = that[0];

      for (var i = 0; i < thisLen; i++) {
        if (this[i] == thatChar) {
          tokCount++;
        }
      }

      return tokCount;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String quote({bool isSingle = false}) {
    var plainQuote = (isSingle ? QUOTE_1 : QUOTE_2);
    var escapedQuote = ESC + plainQuote;

    var result = plainQuote + replaceAll(plainQuote, escapedQuote) + plainQuote;

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  String unquote() {
    var len = length;

    if (len <= 1) {
      return this;
    }

    var plainQuote = this[0];

    if (((plainQuote != '"') && (plainQuote != "'")) || (plainQuote != this[len - 1])) {
      return this;
    }

    var escapedQuote = r'\' + plainQuote;

    var result = substring(1, (len - 2)).replaceAll(escapedQuote, plainQuote);

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}