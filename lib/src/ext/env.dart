import 'dart:io';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';

class Environment {
  static const _DLR = r'$';
  static const _DLR_DLR = r'$$';

  static final RegExp _RE_ENV_VAR_NAME = RegExp(r'\$([A-Z_][A-Z_0-9]*)|\$[\{]([A-Z_][A-Z_0-9\(\)]*)[\}]|\$(#|[0-9]+)|\$[\{](#|[0-9]+)[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  static final bool isWindows = Platform.isWindows;

  //////////////////////////////////////////////////////////////////////////////

  static final String homeKey = (isWindows ? 'USERPROFILE' : 'HOME');

  //////////////////////////////////////////////////////////////////////////////
  // Dependency injection
  //////////////////////////////////////////////////////////////////////////////

  static FileSystem fileSystem = MemoryFileSystem();

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, String> _local = {};

  //////////////////////////////////////////////////////////////////////////////

  static void clearLocal() =>
    _local.clear();

  //////////////////////////////////////////////////////////////////////////////

  static String expand(String input, {List<String>? args, bool canEscape = false}) {
    if ((args != null) && args.isEmpty) {
      args = null;
    }

    var out = StringExt.EMPTY;

    for (var inp in input.split(_DLR_DLR)) {
      if (out.isNotEmpty) {
        out += _DLR;
      }

      out += inp.replaceAllMapped(_RE_ENV_VAR_NAME, (match) {
        var envVarName = (match.group(1) ?? match.group(2) ?? StringExt.EMPTY);

        if (envVarName.isNotEmpty) {
          var newValue = get(envVarName);

          // if (canEscape && newValue.isNotEmpty) {
          //   newValue = newValue.escapeEscapeChar();
          // }

          return newValue;
        }

        if (args != null) {
          var argStr = (match.group(3) ?? match.group(4) ?? StringExt.EMPTY);

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

        return StringExt.EMPTY;
      });
    }
        
    return out;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String get(String key, {String? defValue}) {
    var keyEx = (isWindows ? key.toUpperCase() : key);
    var value = (_local.isEmpty ? null : _local[keyEx]);

    if (value == null) {
      return Platform.environment[keyEx] ?? defValue ?? StringExt.EMPTY;
    }
    else {
      return value;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> getAll({bool isLocalOnly = false}) =>
    <String, String>{}..addAll(_local)..addAll(Platform.environment);

  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> getAllLocal() =>
    <String, String>{}..addAll(_local);

  //////////////////////////////////////////////////////////////////////////////

  static String getHome() =>
    get(homeKey);

  //////////////////////////////////////////////////////////////////////////////

  static void init(FileSystem newFileSystem) {
    Path.init(newFileSystem);
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
      _local[keyEx] = ((value ?? defValue)?.toString() ?? StringExt.EMPTY);
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
}