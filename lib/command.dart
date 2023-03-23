import 'dart:io';
import 'package:thin_logger/thin_logger.dart';
import 'package:xnx/config.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/string.dart';
import 'package:xnx/xnx.dart';

class Command {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const _internalPrint = r'--print';
  static final _shellChars = RegExp.escape('`&;|<>[](){}');
  static final _splitArgRE = RegExp('([^$_shellChars]*)([$_shellChars]+)([^$_shellChars]*)');
  static final _splitArgsRE = RegExp('(\'[^\']*\')|("[^"]*")|([^\\s]+)');

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  List<String> args = [];
  bool isInShell = false;
  bool isInternal = false;
  bool isToVar = false;
  String path = '';

  //////////////////////////////////////////////////////////////////////////////
  // Internals
  //////////////////////////////////////////////////////////////////////////////

  Config? _config;
  Logger? _logger;

  //////////////////////////////////////////////////////////////////////////////

  Command({String? path, List<String>? args, String? text, Config? config, this.isInShell = false, this.isToVar = false, Logger? logger}) {
    _logger = logger;
    _config = config;

    if (text?.isNotEmpty ?? false) {
      if ((path?.isNotEmpty ?? false) || (args?.isNotEmpty ?? false)) {
        throw Exception('Either command text, or executable path with arguments expected');
      }

      split(text);
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
      split(text);
    }

    if (_logger?.isVerbose ?? false) {
      _logger!.verbose('Running command:\n$path ${args.join(' ')}');
    }

    var outLines = '';

    if (isInternal && args.isNotEmpty && (args[0] == _internalPrint)) {
      return print(_logger, args.sublist(1), isToVar: isToVar);
    }

    if (path.isEmpty && !isInternal) {
      return outLines;
    }

    if (canShow && !isInternal) {
      _logger?.out(toString());
    }

    if (!canExec) {
      return outLines;
    }

    ProcessResult? result;
    var errMsg = '';
    var isSuccess = false;

    var oldCurDir = Path.currentDirectory;
    var oldLocEnv = Env.getAllLocal();

    var fullEnv = Env.getAll();

    try {
      if (isInternal) {
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
          runInShell: false,
          workingDirectory: Path.currentDirectoryName
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

    if (!isInternal && (result != null)) {
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
    Path.currentDirectory = oldCurDir;

    if (!isSuccess) {
      throw Exception(errMsg.isEmpty ? '\nExecution failed' : errMsg);
    }

    return outLines.trim();
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getStartCommand({bool escapeQuotes = false}) {
    final path = Platform.resolvedExecutable;
    final args = <String>[];

    var scriptPath = Platform.script.path;

    if (Path.basenameWithoutExtension(path) !=
        Path.basenameWithoutExtension(scriptPath)) {
      args.add(scriptPath);
    }

    args.addAll(Platform.executableArguments);

    return Command(path: path, args: args).toString();
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

  Command split(String? input) {
    args.clear();
    path = '';
    isInternal = false;

    var inputEx = input?.trim() ?? '';

    if (inputEx.isEmpty) {
      return this;
    }

    _splitArgs(inputEx);

    if (inputEx[0] == _internalPrint[0]) {
      isInternal = true;
      return this;
    }
    
    if (!isInShell) {
      isInShell = args.any((x) => _shellChars.contains(x));
    }
    
    if (!isInShell || Env.isShell(path, _config?.keywords.shellNames)) {
      return this;
    }

    if (Env.isWindows) {
      args.insertAll(0, [Env.shellOpt, path]);
    } else {
      inputEx = _removePath(inputEx, path);
      args = [Env.shellOpt, '${path.quote()} $inputEx'];
    }

    path = Env.getShell();

    return this;
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

    if (!isInternal && path.isEmpty) {
      path = arg.unquote();
    } else {
      args.add(arg.unquote());
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String _removePath(String input, String path) {
    var pathLen = path.length;

    if (input.length < pathLen) {
      return input;
    }

    switch (input[0]) {
      case StringExt.apos:
      case StringExt.quot:
        pathLen += 2;
        break;
      default:
        break;
    }

    return input.substring(pathLen).trim();
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _splitArg(String input) {
    var wasSplit = false;

    input.replaceAllMapped(_splitArgRE, (m) {
      wasSplit = true;

      for (var i = 1; i <= 3; i++) {
        var sub = m.group(i);

        if ((sub != null) && sub.isNotEmpty) {
          _addArg(sub);
        }
      }

      return '';
    });

    return wasSplit;
  }

  //////////////////////////////////////////////////////////////////////////////

  Command _splitArgs(String input) {
    args.clear();

    input.replaceAllMapped(_splitArgsRE, (m) {
      for (var i = 1; i <= 3; i++) {
        var arg = m.group(i);

        if (arg == null) {
          continue;
        }

        if ((i != 3)  || !_splitArg(arg)) {
          _addArg(arg);
        }
      }

      return '';
    });

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

}
