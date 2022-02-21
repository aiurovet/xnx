import 'dart:io';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/xnx.dart';

class Command {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const _localPrint = r'--print';
  static const _optionChars = r'-+';
  static const _shellChars = '|<>()&;';

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  List<String> args = [];
  bool isLocal = false;
  bool isShellRequired = false;
  bool isToVar = false;
  String path = '';

  //////////////////////////////////////////////////////////////////////////////
  // Internals
  //////////////////////////////////////////////////////////////////////////////

  Logger? _logger;

  //////////////////////////////////////////////////////////////////////////////

  Command({String? path, List<String>? args, String? text, this.isToVar = false, Logger? logger}) {
    _logger = logger;

    if (text?.isNotEmpty ?? false) {
      if ((path?.isNotEmpty ?? false) || (args?.isNotEmpty ?? false)) {
        throw Exception('Either command text, or executable path with arguments expected');
      }

      parse(text);
    }
    else {
      if (path != null) {
        this.path = path;
      }
      if (args != null) {
        if (this.path.isNotEmpty) {
          this.args = args;
        }
        else {
          this.path = args[0];
          this.args = args.sublist(1);
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String exec({String? text, bool canExec = true, bool canShow = true}) {
    if (text != null) {
      parse(text);
    }

    var outLines = '';

    if (isLocal && args.isNotEmpty && (args[0] == _localPrint)) {
      return print(_logger, args.sublist(1), isToVar: isToVar);
    }

    if (path.isEmpty && !isLocal) {
      return outLines;
    }

    if (canShow && !isLocal) {
      _logger?.out(toString());
    }

    if (!canExec) {
      return outLines;
    }

    ProcessResult? result;
    var errMsg = '';
    var isSuccess = false;

    var oldCurDir = Path.fileSystem.currentDirectory;
    var oldLocEnv = Env.getAllLocal();

    var fullEnv = Env.getAll();

    try {
      if (isLocal) {
        Xnx(logger: _logger).exec(args);
        isSuccess = true;
      }
      else {
        if (path.isBlank()) {
          // Shouldn't happen, but just in case
          throw Exception('Executable is not defined for $args');
        }

        result = Process.runSync(path, args,
          environment: fullEnv,
          runInShell: isShellRequired,
          workingDirectory: Path.currentDirectory.path
        );

        isSuccess = (result.exitCode == 0);
      }
    }
    on Error catch (e) {
      errMsg = e.toString();
    }
    on Exception catch (e) {
      errMsg = e.toString();
    }

    if (!isLocal && (result != null)) {
      if (result.stdout?.isNotEmpty ?? false) {
        outLines = result.stdout;
      }

      if (isSuccess) {
        if (!isToVar) {
          _logger?.out(outLines);
          outLines = '';
        }
      }
      else {
        _logger?.error('Exit code: ${result.exitCode}');
        _logger?.error('\n*** Error:\n\n${result.stderr ?? 'No error or warning message found'}');
      }
    }

    Env.setAllLocal(oldLocEnv);
    Path.fileSystem.currentDirectory = oldCurDir;

    if (!isSuccess) {
      throw Exception(errMsg.isEmpty ? '\nExecution failed' : errMsg);
    }

    return outLines.trim();
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getStartCommand({bool escapeQuotes = false}) {
    var path = Platform.resolvedExecutable;
    var args = <String>[];

    var scriptPath = Platform.script.path;

    if (Path.basenameWithoutExtension(path) !=
        Path.basenameWithoutExtension(scriptPath)) {
      args.add(scriptPath);
    }

    args.addAll(Platform.executableArguments);

    return Command(path: path, args: args).toString();
  }

  //////////////////////////////////////////////////////////////////////////////

  Command parse(String? input, {bool isFull = true}) {
    args.clear();

    path = '';
    isLocal = false;
    isShellRequired = false;

    var buffer = input?.trim() ?? '';

    if (buffer.isEmpty) {
      return this;
    }

    var isArgEnd = false;
    var isEscape = false;
    var isQuoted = 0;

    var currChar = '';
    var nextChar = currChar;
    var arg = '';

    for (var currNo = 0, lastNo = buffer.length - 1; ; currNo++) {
      if (currNo > lastNo) {
        if (arg.isNotEmpty) {
          _addArg(arg);
        }
        break;
      }

      currChar = (currNo == 0 ? buffer[0] : nextChar);
      nextChar = (currNo < lastNo ? buffer[currNo + 1] : '');

      if ((currChar == Env.escape) && !isEscape) {
        isEscape = true;
        continue;
      }
      if (isEscape) {
        isEscape = false;
      }
      else if ((currChar == ' ') || (currChar == '\t')) {
        if (arg.isEmpty) {
          continue;
        }
        isArgEnd = (isQuoted <= 0);
      }
      else if (currChar == "'") {
        if (isQuoted <= 0) {
          isQuoted = 1;
          continue;
        }
        else if (isQuoted == 1) {
          isQuoted = 0;
          isArgEnd = true;
        }
      }
      else if (currChar == '"') {
        if (isQuoted <= 0) {
          isQuoted = 2;
          continue;
        }
        else if (isQuoted == 2) {
          isQuoted = 0;
          isArgEnd = true;
        }
      }
      else {
        if ((isQuoted == 0) && _shellChars.contains(currChar)) {
          if (isFull) {
            isShellRequired = true;
            _addArg(arg);
            arg = currChar;
          }
          else {
            currNo = lastNo; // stop to avoid shell command injection
          }
          isArgEnd = true;
        }
      }

      if (isArgEnd) {
        _addArg(arg);
        arg = '';
        isArgEnd = false;
      }
      else {
        arg += currChar;
      }
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String print(Logger? logger, List<String> args, {bool isSilent = false, bool isToVar = false}) {
    var out = args.join(' ');

    if (isToVar) {
      return out.trim();
    }
    else if (!isSilent) {
      logger?.out(out);
    }

    return '';
  }

  //////////////////////////////////////////////////////////////////////////////

  @override
  String toString() {
    var str = path.quote();

    for (var arg in args) {
      if (str.isNotEmpty) {
        str += ' ';
      }
      str += arg.quote();
    }

    return str;
  }

  //////////////////////////////////////////////////////////////////////////////

  void _addArg(String arg) {
    if (arg.isEmpty) {
      return;
    }

    var firstChar = arg[0];

    var hasPath = (path.isNotEmpty || isLocal);

    if (!hasPath) {
      isLocal = _optionChars.contains(firstChar);
      hasPath = isLocal;
    }

    if (hasPath) {
      args.add(arg);
    }
    else {
      path = arg;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}
