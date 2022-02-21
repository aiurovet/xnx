import 'dart:io';
import 'package:file/file.dart';
import 'package:xnx/src/ext/ascii.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';

class Env {

  //////////////////////////////////////////////////////////////////////////////

  static final bool isWindows = Platform.isWindows;

  static String escape = r'\'; // for any OS
  static String escapeEscape = (escape + escape);
  static String escapePosix = escape; // Linux, macOS et al
  static String escapeWin = r'^'; // Windows

  static final String homeKey = (isWindows ? 'USERPROFILE' : 'HOME');
  static final String userKey = (isWindows ? 'USERNAME' : 'USER');

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, String> _local = {};

  //////////////////////////////////////////////////////////////////////////////

  static void clearLocal() => _local.clear();

  //////////////////////////////////////////////////////////////////////////////

  static String expand(String input, {List<String>? args, bool canEscape = false}) {
    var argCount = (args?.length ?? 0);

    if (argCount <= 0) {
      args = null;
    }

    var braceCount = 0;
    var currCodeUnit = 0;
    var envVarName = '';
    var fromPos = -1;
    var hasBraces = false;
    var isEscaped = false;
    var isSpecialAllowed = false;
    var nextCodeUnit = 0;
    var result = '';

    for (var currPos = 0, lastPos = input.length - 1; currPos <= lastPos; currPos++) {
      currCodeUnit = input.codeUnitAt(currPos); // (currPos == 0 ? input.codeUnitAt(0) : nextCodeUnit);
      nextCodeUnit = (currPos < lastPos ? input.codeUnitAt(currPos + 1) : 0);

      switch (currCodeUnit) {
        case Ascii.backSlash:
          isEscaped = !isEscaped;

          if (nextCodeUnit == Ascii.dollar) {
            if (isEscaped) {
              ++currPos;
            }
            else {
              continue;
            }
          }
          break;
        case Ascii.dollar:
          isEscaped = false;
          hasBraces = (nextCodeUnit == Ascii.braceOpen);

          if (!hasBraces &&
              ((nextCodeUnit < Ascii.lowerA) || (nextCodeUnit > Ascii.lowerZ)) &&
              ((nextCodeUnit < Ascii.upperA) || (nextCodeUnit > Ascii.upperZ)) &&
              (nextCodeUnit != Ascii.asterisk) &&
              (nextCodeUnit != Ascii.at) &&
              (nextCodeUnit != Ascii.hash) &&
              (currCodeUnit != Ascii.parenthesisOpen) &&
              (currCodeUnit != Ascii.parenthesisShut) &&
              (nextCodeUnit != Ascii.tilde)) {
            break;
          }

          braceCount = (hasBraces ? 1 : 0);
          envVarName = '';
          isSpecialAllowed = true;

          if (hasBraces) {
            ++currPos;
          }

          for (fromPos = (++currPos); envVarName.isEmpty; currPos++) {
            if (envVarName.isNotEmpty) {
              break;
            }
            if (currPos > lastPos) {
              envVarName = input.substring(fromPos, currPos);

              if (braceCount > 0) {
                throw Exception('Unclosed environment variable $envVarName');
              }
              break;
            }

            currCodeUnit = input.codeUnitAt(currPos);
            nextCodeUnit = (currPos < lastPos ? input.codeUnitAt(currPos + 1) : 0);

            switch (currCodeUnit) {
              case Ascii.braceOpen:
                if (hasBraces) {
                  ++braceCount;
                }
                else {
                  envVarName = input.substring(fromPos, currPos);
                }
                continue;
              case Ascii.braceShut:
                if (!hasBraces || (--braceCount) <= 0) {
                  envVarName = input.substring(fromPos, currPos);
                }
                continue;
              default:
                if (braceCount > 0) {
                  continue;
                }
                if ((currCodeUnit == Ascii.tilde)) {
                  continue;
                }
                else if ((currCodeUnit == Ascii.asterisk) ||
                    (currCodeUnit == Ascii.at) ||
                    (currCodeUnit == Ascii.hash)) {
                  if (isSpecialAllowed) {
                    isSpecialAllowed = hasBraces;
                    continue;
                  }
                }
                else if (((currCodeUnit >= Ascii.lowerA) && (currCodeUnit <= Ascii.lowerZ)) ||
                    ((currCodeUnit >= Ascii.upperA) && (currCodeUnit <= Ascii.upperZ)) ||
                    ((currCodeUnit >= Ascii.digitZero) && (currCodeUnit <= Ascii.digitNine)) ||
                    (currCodeUnit == Ascii.parenthesisOpen) ||
                    (currCodeUnit == Ascii.parenthesisShut) ||
                    (currCodeUnit == Ascii.tilde) ||
                    (currCodeUnit == Ascii.underscore)) {
                  isSpecialAllowed = hasBraces;
                  continue;                  
                }

                envVarName = input.substring(fromPos, currPos);

                if (envVarName.isNotEmpty) {
                  --currPos;
                }

                continue;
            }
          }
          break;
        default:
          isEscaped = false;
          break;
      }

      if (envVarName.isNotEmpty) {
        var isLength = (envVarName[0] == '#');

        if (isLength) {
          envVarName = envVarName.substring(1);
        }

        var argNo = (envVarName.startsWith('~') ? int.tryParse(envVarName.substring(1), radix: 10) ?? 0 : 0);
        var value = '';

        if (argNo != 0) {
          if ((argNo > 0) && (argNo <= argCount) && (args != null)) {
            value = args[argNo - 1];
          }
        }
        else if (envVarName.isEmpty) {
          if (isLength) {
            value = (args?.length ?? 0).toString();
            isLength = false;
          }
        }
        else {
          switch (envVarName) {
            case '*':
            case '@':
            case '~*':
            case '~@':
              if (args != null) {
                value = args.map((x) => x.quote()).join(' ');
              }
              break;
            case '~#':
              if (args != null) {
                value = args.length.toString();
              }
              break;
            default:
              value = get(envVarName);
              break;
          }
        }

        if (value.isEmpty) {
          var breakPos = envVarName.indexOf(':');

          if (value.isEmpty && (breakPos >= 0) && (breakPos < (envVarName.length - 1) && '-='.contains(envVarName[breakPos + 1]))) {
            value = expand(envVarName.substring(breakPos + 2), args: args, canEscape: canEscape);
          }
        }

        if (isLength) {
          result += value.length.toString();
        }
        else if (value.isNotEmpty) {
          if (canEscape) {
            value = value.replaceAll(escape, escapeEscape);
          }
          result += value;
        }

        envVarName = '';

        if (currCodeUnit == Ascii.dollar) {
          --currPos;
          continue;
        }
      }

      if (currPos <= lastPos) {
        result += input[currPos];
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String get(String key, {String? defValue}) {
    var keyEx = (isWindows ? key.toUpperCase() : key);

    var value = (_local.isEmpty ? null : _local[keyEx]);
    value ??= Platform.environment[keyEx] ?? defValue ?? '';

    return value;
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
