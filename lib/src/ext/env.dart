import 'dart:io';
import 'package:file/file.dart';
import 'package:xnx/src/ext/path.dart';

class Env {
  static const _DOLLAR = r'$';
  static const _DOLLAR_DOLLAR = r'$$';

  static final RegExp _RE_ENV_VAR_NAME = RegExp(
      r'\$([A-Z_][A-Z_0-9]*)|\$[\{]([A-Z_][A-Z_0-9\(\)]*)[\}]|\$(#|[0-9]+)|\$[\{](#|[0-9]+)[\}]',
      caseSensitive: false
  );

  //////////////////////////////////////////////////////////////////////////////

  static final bool isWindows = Platform.isWindows;

  static String escape = r'\'; // for any OS
  static String escapeEscape = (escape + escape);

  static final String homeKey = (isWindows ? 'USERPROFILE' : 'HOME');

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, String> _local = {};

  //////////////////////////////////////////////////////////////////////////////

  static void clearLocal() => _local.clear();

  //////////////////////////////////////////////////////////////////////////////

  static String expand(String input, {List<String>? args, bool canEscape = false}) {
    if ((args != null) && args.isEmpty) {
      args = null;
    }

    var out = '';

    for (var inp in input.split(_DOLLAR_DOLLAR)) {
      if (out.isNotEmpty) {
        out += _DOLLAR;
      }

      out += inp.replaceAllMapped(_RE_ENV_VAR_NAME, (match) {
        var envVarName = (match.group(1) ?? match.group(2) ?? '');

        if (envVarName.isNotEmpty) {
          var newValue = get(envVarName);

          if (canEscape && newValue.isNotEmpty) {
             newValue = newValue.replaceAll(escape, escapeEscape);
          }

          return newValue;
        }

        if (args != null) {
          var argStr = (match.group(3) ?? match.group(4) ?? '');

          if (argStr == '#') {
            return args.length.toString();
          }

          var argNo = int.tryParse(argStr, radix: 10);

          if (argNo != null) {
            if ((argNo > 0) && (argNo <= args.length)) {
              return args[argNo - 1];
            }
          }
        }

        return '';
      });
    }

    return out;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String get(String key, {String? defValue}) {
    var keyEx = (isWindows ? key.toUpperCase() : key);
    var value = (_local.isEmpty ? null : _local[keyEx]);

    if (value == null) {
      return Platform.environment[keyEx] ?? defValue ?? '';
    }
    else {
      return value;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> getAll({bool isLocalOnly = false}) =>
      <String, String>{}
        ..addAll(_local)
        ..addAll(Platform.environment);

  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> getAllLocal() =>
      <String, String>{}..addAll(_local);

  //////////////////////////////////////////////////////////////////////////////

  static String getHome() => get(homeKey);

  //////////////////////////////////////////////////////////////////////////////

  static Directory getHomeDirectory() => Path.fileSystem.directory(getHome());

  //////////////////////////////////////////////////////////////////////////////

  static void init({FileSystem? fileSystem}) {
    Path.init(fileSystem);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void set<T>(String key, T value, {T? defValue}) {
    var keyEx = (isWindows ? key.toUpperCase() : key);

    if (Platform.environment.containsKey(keyEx)) {
      throw Exception('Changing system environment is prohibited');
    }

    if ((value == null) && (defValue == null)) {
      _local.remove(keyEx);
    }
    else {
      _local[keyEx] = ((value ?? defValue)?.toString() ?? '');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void setAllLocal(Map<String, String> from) {
    _local.clear();

    if (from.isNotEmpty) {
      _local.addAll(from);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void setEscape([String? newEscape]) {
    escape = newEscape ?? r'\';
    escapeEscape = escape + escape;
  }

  //////////////////////////////////////////////////////////////////////////////
}
