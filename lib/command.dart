import 'dart:io';
import 'package:shell_cmd/shell_cmd.dart';
import 'package:thin_logger/thin_logger.dart';
import 'package:xnx/config.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/string.dart';
import 'package:xnx/xnx.dart';

class Command extends ShellCmd {
  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const _internalPrint = r'--print';

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  bool isInShell = false;
  bool isInternal = false;
  bool isToVar = false;

  //////////////////////////////////////////////////////////////////////////////
  // Internals
  //////////////////////////////////////////////////////////////////////////////

  Logger? _logger;

  //////////////////////////////////////////////////////////////////////////////

  Command(
      {String? source, Config? config, this.isToVar = false, Logger? logger})
      : super(source) {
    _logger = logger;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void chmod(int newMode, String path) {
    // Skip if the OS is Windows: no chmod there

    if (Env.isWindows || (newMode == 0)) {
      return;
    }

    // Get curent mode

    final curStat = File(path).statSync();
    final isFound = (curStat.type != FileSystemEntityType.notFound);
    final curMode = (isFound ? (curStat.mode & 0x1FF) : null);

    // Skip if the file is not found or the mode is the same

    newMode = newMode & 0x1FF; // UNIX permissions only

    if ((curMode == null) || (newMode == curMode)) {
      return;
    }

    // Execute the mode change

    var text = 'chmod ${newMode.toRadixString(8)} "$path"';
    Command(source: text).exec();
  }

  //////////////////////////////////////////////////////////////////////////////

  String exec(
      {String? newText,
      bool canExec = true,
      bool? runInShell,
      bool canShow = true}) {
    if (newText != null) {
      parse(newText);
    }

    if (_logger?.isVerbose ?? false) {
      _logger!.verbose('Running command:\n$text');
    }

    var outLines = '';

    if (program.isEmpty) {
      return outLines;
    }

    if (isInternal && args.isNotEmpty) {
      if (program == _internalPrint) {
        return print(_logger, args, isToVar: isToVar);
      }
    }

    if (canShow && !isInternal) {
      _logger?.out(text);
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
        args.insert(0, program);
        Xnx(logger: _logger).exec(args);
        isSuccess = true;
      } else {
        if (program.isBlank()) {
          // Shouldn't happen, but just in case
          throw Exception('Executable is not defined for $text');
        }

        result = runSync(environment: fullEnv, runInShell: runInShell);
        isSuccess = (result.exitCode == 0);
      }
    } on Error catch (e) {
      errMsg = e.toString();
    } on Exception catch (e) {
      errMsg = e.toString();
    }

    if (!isInternal && (result != null)) {
      outLines = result.stdout ?? '';

      if (isSuccess) {
        if (!isToVar) {
          _logger?.out(outLines);
          outLines = '';
        }
      } else {
        _logger?.error('Exit code: ${result.exitCode}');
        _logger?.error(
            '\n*** Error:\n\n${result.stderr ?? 'No error or warning message found'}');
      }
    }

    Env.setAllLocal(oldLocEnv);
    Path.currentDirectory = oldCurDir;

    if (!isSuccess) {
      throw Exception(errMsg.isEmpty ? '\nExecution failed' : errMsg);
    }

    return outLines;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getStartCommandText({bool escapeQuotes = false}) {
    final program = Platform.resolvedExecutable;
    final args = <String>[];

    var scriptPath = Platform.script.path;

    if (Path.basenameWithoutExtension(program) !=
        Path.basenameWithoutExtension(scriptPath)) {
      args.add(scriptPath);
    }

    args.addAll(Platform.executableArguments);

    return ShellCmd.fromParsed(program, args).text;
  }

  //////////////////////////////////////////////////////////////////////////////

  @override
  void parse([String? text]) {
    super.parse(text);
    isInternal = program.startsWith('-');
  }

  //////////////////////////////////////////////////////////////////////////////

  static String print(Logger? logger, List<String> args,
      {bool isSilent = false, bool isToVar = false}) {
    var out = args.join(' ');

    if (isToVar) {
      return out.trim();
    } else if (!isSilent) {
      logger?.out(out);
    }

    return '';
  }

  //////////////////////////////////////////////////////////////////////////////
}
