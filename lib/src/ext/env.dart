import 'dart:io';
import 'package:file/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';

class Env {
  static const _dollar = r'$';
  static const _dollarDollar = r'$$';

  static final RegExp _rexEnvVarName = RegExp(
      r'\$([A-Z_][A-Z_0-9]*)|\$[\{]([A-Z_][A-Z_0-9\(\)]*)[\}]|\$(\*|\@|#|~[0-9]+)|\$[\{](\*|\@|#|~[0-9]+)[\}]',
      caseSensitive: false
  );

  //////////////////////////////////////////////////////////////////////////////

  static final bool isWindows = Platform.isWindows;

  static String escape = r'\'; // for any OS
  static String escapeEscape = (escape + escape);

  static final String homeKey = (isWindows ? 'USERPROFILE' : 'HOME');
  static final String userKey = (isWindows ? 'USERNAME' : 'USER');

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

    for (var inp in input.split(_dollarDollar)) {
      if (out.isNotEmpty) {
        out += _dollar;
      }

      out += inp.replaceAllMapped(_rexEnvVarName, (match) {
        var envVarName = (match.group(1) ?? match.group(2) ?? '');
        var newValue = '';

        if (envVarName.isNotEmpty) {
          newValue = get(envVarName);

          if (canEscape && newValue.isNotEmpty) {
             newValue = newValue.replaceAll(escape, escapeEscape);
          }

          return newValue;
        }
        else {
          if (args != null) {
            var argStr = (match.group(3) ?? match.group(4) ?? '');

            switch (argStr) {
              case '*':
              case '@':
                newValue = args.map((x) => x.quote()).join(' ');
                break;
              case '#':
                newValue = args.length.toString();
                break;
              default:
                var argNo = int.tryParse(argStr.substring(1), radix: 10);

                if (argNo != null) {
                  if ((argNo > 0) && (argNo <= args.length)) {
                    newValue = args[argNo - 1];
                  }
                }
                break;
            }

            if (argStr == '#') {
            }
            else {
            }
          }
        }

        if (canEscape && newValue.isNotEmpty) {
          newValue = newValue.replaceAll(escape, escapeEscape);
        }

        return newValue;
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
        ..addAll(Platform.environment)
        ..addAll(_local);

  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> getAllLocal() =>
      <String, String>{}..addAll(_local);

  //////////////////////////////////////////////////////////////////////////////

  static String getHome() => get(homeKey);
  static Directory getHomeDirectory() => Path.fileSystem.directory(getHome());
  static String getOs() => Platform.operatingSystem;
  static String getUser() => get(userKey);

  //////////////////////////////////////////////////////////////////////////////

  static void init({FileSystem? fileSystem}) {
    Path.init(fileSystem);

    if (isWindows) {
      set('HOME', Env.getHome());
      set('USER', Env.getUser());
    }

    set('HOST', Platform.localHostname);
    set('LOCALE', Platform.localeName);
    set('OS', Platform.operatingSystem);
    set('OS_FULL', Platform.operatingSystemVersion);
    set('TEMP', Path.fileSystem.systemTempDirectory.path);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void set<T>(String key, T value, {T? defValue}) {
    var keyEx = (isWindows ? key.toUpperCase() : key);

    if ((value == null) && (defValue == null)) {
      _local.remove(keyEx);
    }
    else {
      var sysValue = Platform.environment[keyEx];
      var newValue = ((value ?? defValue)?.toString() ?? '');

      if (newValue != sysValue) {
        _local[keyEx] = newValue;
      }
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
