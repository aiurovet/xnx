import 'dart:io';
import 'package:file/file.dart';
import 'package:xnx/ext/ascii.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/string.dart';

class Env {

  //////////////////////////////////////////////////////////////////////////////

  static final bool isMacOS = Platform.isMacOS;
  static final bool isWindows = Platform.isWindows;
  static final String searchPathSeparator = (isWindows ? ';' : ':');

  static String escape = getDefaultEscape();
  static const String escapePosix = r'\';
  static const String escapeWin = '^';
  static String escapeApos = escape + StringExt.apos;
  static String escapeEscape = (escape + escape);
  static String escapeQuot = escape + StringExt.quot;

  static final String homeKey = (isWindows ? 'USERPROFILE' : 'HOME');
  static final String pathKey = 'PATH';
  static final String userKey = (isWindows ? 'USERNAME' : 'USER');
  static final String shellKey = (isWindows ? 'COMSPEC' : 'SHELL');
  static final String shellOpt = (isWindows ? '/c' : '-c');

  //////////////////////////////////////////////////////////////////////////////
  // Avoid prepending any command with shell if its first argument's basename
  // without extension represents one of the strings below. The extension is 
  // checked as being empty, could also be either '.exe' or '.com' (Windows)
  //
  // Configurable via *.xnxconfig
  //////////////////////////////////////////////////////////////////////////////

  static final _shellExtns = (isWindows ? <String>[ '', 'exe', 'com' ] : <String>[ '' ]);

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

    var argNo = 0;
    var braceCount = 0;
    var currCodeUnit = 0;
    var envVarName = '';
    var fromPos = -1;
    var hasBraces = false;
    var isArg = false;
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

          if (!hasBraces) {
            if (((nextCodeUnit < Ascii.lowerA) || (nextCodeUnit > Ascii.lowerZ)) &&
                ((nextCodeUnit < Ascii.upperA) || (nextCodeUnit > Ascii.upperZ)) &&
                (nextCodeUnit != Ascii.asterisk) &&
                (nextCodeUnit != Ascii.at) &&
                (nextCodeUnit != Ascii.hash) &&
                (nextCodeUnit != Ascii.parenthesisOpen) &&
                (nextCodeUnit != Ascii.parenthesisShut) &&
                (nextCodeUnit != Ascii.tilde)) {
              break;
            }
            if ((nextCodeUnit >= Ascii.digitZero) && (nextCodeUnit <= Ascii.digitNine)) {
              break;
            }
          }

          if (hasBraces) {
            var thirdPos = (currPos + 2);
            var thirdCodeUnit = (thirdPos <= lastPos ? input.codeUnitAt(thirdPos) : 0);

            if (thirdCodeUnit == Ascii.braceOpen) {
              break;
            }
          }

          isArg = (nextCodeUnit == Ascii.tilde);
          braceCount = (hasBraces ? 1 : 0);
          envVarName = '';
          isSpecialAllowed = true;

          if (hasBraces) {
            ++currPos;
          }

          // ignore: dead_code
          for (fromPos = ++currPos; envVarName.isEmpty; currPos++) {
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

          if (!isArg) {
            argNo = int.tryParse(isArg ? envVarName.substring(1) : envVarName) ?? 0;

            if (argNo > 0) {
              result += (hasBraces ? '\${$argNo}' : '\$$argNo'.toString());
              --currPos;
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

        argNo = (envVarName.startsWith('~') ? int.tryParse(envVarName.substring(1), radix: 10) ?? 0 : 0);
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
    if (key.isEmpty) {
      return key;
    }

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

  static String getDefaultEscape() => (isWindows ? escapeWin : escapePosix);
  static String getDefaultShell() => (isMacOS ? 'zsh' : (isWindows ? 'cmd' : 'bash'));
  static String getHome() => get(homeKey);
  static Directory getHomeDirectory() => Path.fileSystem.directory(getHome());
  static String getOs() => Platform.operatingSystem;
  static String getUser() => get(userKey);

  //////////////////////////////////////////////////////////////////////////////

  static String getShell({bool isQuoted = false}) {
    final path = get(shellKey);
    
    if (path.isEmpty) {
      return getDefaultShell();
    }

    return (isQuoted ? path.quote() : path);
  }

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

  static bool isShell(String? command, List<String>? shellNames) {
    if ((shellNames == null) || (command == null) || command.isEmpty) {
      return false;
    }

    command = command.unquote().trim();

    if (command.isEmpty || (command == getShell())) {
      return false;
    }

    if (!_shellExtns.contains(Path.extension(command))) {
      return false;
    }

    if (!shellNames.contains(Path.basenameWithoutExtension(command))) {
      return false;
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void set<T>(String key, T value, {T? defValue}) {
    if (key.isEmpty) {
      return;
    }

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

  static void setEscape({String? char, FileSystem? fileSystem}) {
    if (char != null) {
      escape = char;
    } else if (fileSystem != null) {
      escape = (Path.isWindowsFS ? escapeWin : escapePosix);
    } else {
      escape = getDefaultEscape();
    }

    escapeEscape = (escape + escape);
    escapeApos = escape + StringExt.apos;
    escapeQuot = escape + StringExt.quot;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String which(String subPath, {bool canThrow = false}) {
    subPath = Path.adjust(subPath);

    if (!Path.isAbsolute(subPath)) {
      final topPaths = Env.get(Env.pathKey).split(Env.searchPathSeparator);

      for (var topPath in topPaths) {
        final fullPath = Path.join(topPath, subPath);

        if (Path.fileSystem.file(fullPath).existsSync()) {
          return fullPath;
        }
      }
    }

    if (canThrow) {
      throw Exception('$subPath is not found under any of ${Env.pathKey} directories');
    }

    return '';
  }

  //////////////////////////////////////////////////////////////////////////////

}
