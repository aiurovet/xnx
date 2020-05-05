import 'dart:core';
import 'dart:io';
import 'package:path/path.dart' as Path;

extension StringExt on String {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> ENVIRONMENT;

  static final bool IS_WINDOWS = Platform.isWindows;
  static final String ESC_CHAR = (IS_WINDOWS ? r'^' : r'\');
  static final String ESC_CHAR_ESC = (IS_WINDOWS ? r'\^' : r'\\');

  static final RegExp BLANK = RegExp(r'^[\s]*$');

  static const String EMPTY = '';
  static const int EOT_CODE = 4;
  static final String EOT = String.fromCharCode(StringExt.EOT_CODE);
  static const String FALSE_STR = 'false';
  static const String NEWLINE = '\n';
  static const String SPACE = ' ';
  static const String TAB = '\t';
  static const String TRUE = 'true';
  static const String FALSE = 'false';

  static const String STDIN_DISP = '<stdin>';
  static const String STDIN_PATH = '-';

  static const String STDOUT_DISP = '<stdout>';
  static const String STDOUT_PATH = StringExt.STDIN_PATH;

  static final RegExp RE_ENV_VAR_NAME = RegExp(r'\$([A-Z_][A-Z_0-9]*)|\$[\{]([A-Z_][A-Z_0-9]*)[\}]', caseSensitive: false);
  static final RegExp RE_PATH_SEP = RegExp(r'[\/\\]');
  static final RegExp RE_PROTOCOL = RegExp(r'^[A-Z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  String adjustPath() {
    var adjustedPath = trim().replaceAll(RE_PATH_SEP, Platform.pathSeparator);

    return adjustedPath;
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandEnvironmentVariables({List<String> args}) {
    if (ENVIRONMENT == null) {
      _initEnvironmentVariables();
    }

    var argCount = (args?.length ?? 0);

    var result =
       replaceAll(r'\\', '\x01')
      .replaceAll(r'\$', '\x02')
      .replaceAll(r'$$', '\x03')
      .replaceAllMapped(RE_ENV_VAR_NAME, (match) {
        var envVarName = (match.group(1) ?? match.group(2));

        if (argCount > 0) {
          var argNo = int.tryParse(envVarName, radix: 10);

          if (argNo != null) {
            return args[argNo - 1];
          }
        }

        if (IS_WINDOWS) {
          envVarName = envVarName.toUpperCase();
        }

        if (ENVIRONMENT.containsKey(envVarName)) {
          return ENVIRONMENT[envVarName];
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

  String quote({bool isSingle = false}) {
    var plainQuote = (isSingle ? "'" : '"');
    var escapedQuote = r'\' + plainQuote;

    var result = plainQuote + replaceAll(plainQuote, escapedQuote) + plainQuote;

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}