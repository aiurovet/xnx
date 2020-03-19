import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:process_run/shell_run.dart';

import 'config.dart';
import 'log.dart';
import 'options.dart';
import 'ext/stdin.dart';
import 'ext/string.dart';

class Convert {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String FILE_TYPE_TMP = '.tmp';

  //////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////

  static bool canExpandEnv;
  static bool canExpandInp;
  static String command;
  static String inpFilePath;
  static bool isExpandInpOnly;
  static bool isStdIn;
  static bool isStdOut;
  static String outDirName;
  static String outFilePath;
  static String tmpFilePath;
  static List<String> commands;

  //////////////////////////////////////////////////////////////////////////////

  static String commandToDisplayString(String cmd) {
    if (cmd == null) {
      return StringExt.EMPTY;
    }
    else if (isExpandInpOnly) {
      return cmd + ': "${outFilePath}"';
    }
    else {
      return cmd.replaceAll(Config.PARAM_NAME_INP, inpFilePath);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future exec(List<String> args) async {
    var maps = Config.exec(args);
    commands = [];

    for (var map in maps) {
      expandMap(map);

      canExpandEnv = StringExt.parseBool(Config.getValue(map, Config.PARAM_NAME_EXP_ENV, canExpand: false));
      canExpandInp = StringExt.parseBool(Config.getValue(map, Config.PARAM_NAME_EXP_INP, canExpand: false));
      command = Config.getValue(map, Config.PARAM_NAME_CMD, canExpand: false);

      var curDir = (Config.getValue(map, Config.PARAM_NAME_CUR_DIR, canExpand: false) ?? StringExt.EMPTY);
      curDir = curDir.getFullPath();

      if (StringExt.isNullOrBlank(command)) {
        throw Exception('Undefined command for\n\n${map.toString()}');
      }

      inpFilePath = Config.getValue(map, Config.PARAM_NAME_INP, canExpand: false);

      if (StringExt.isNullOrBlank(inpFilePath)) {
        throw Exception('Undefined input for\n\n${map.toString()}');
      }

      outFilePath = Config.getValue(map, Config.PARAM_NAME_OUT, canExpand: false);

      if (StringExt.isNullOrBlank(outFilePath)) {
        throw Exception('Undefined output for\n\n${map.toString()}');
      }

      inpFilePath = path.join(curDir, inpFilePath).getFullPath();
      outFilePath = path.join(curDir, outFilePath).getFullPath();

      isExpandInpOnly = (command == Config.CMD_EXPAND);
      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);

      outDirName = (isStdOut ? StringExt.EMPTY : path.dirname(outFilePath));

      if (isStdOut && !isExpandInpOnly) {
        throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
      }

      var actualInpFilePath = getActualInpFilePath();
      tmpFilePath = (isExpandInpOnly || !canExpandInp ? null : actualInpFilePath);

      command = command
          .replaceAll(Config.PARAM_NAME_OUT, outFilePath)
          .replaceAll(Config.PARAM_NAME_INP, actualInpFilePath);

      if (commands.contains(command)) {
        continue;
      }

      commands.add(command);

      var outFile = File(outFilePath);

      if (outFile.existsSync()) {
        outFile.deleteSync();
      }

      if (canExpandInp) {
        expandInpFile(map);
      }

      var isVerbose = Log.isDetailed();

      if (Options.isListOnly || isExpandInpOnly || !isVerbose) {
        Log.outInfo(commandToDisplayString(command));
      }

      if (Options.isListOnly) {
        continue;
      }

      var exitCodes = await Shell(verbose: isVerbose).run(command);

      if (exitCodes.first.exitCode != 0) {
        throw Exception('Command failed${isVerbose ? StringExt.EMPTY : '\n\n' + commandToDisplayString(command) + '\n\n'}');
      }

      if (tmpFilePath != null) {
        var tmpFile = File(tmpFilePath);

        if (tmpFile.existsSync()) {
          tmpFile.deleteSync();
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static File expandInpFile(Map<String, String> map) {
    var text = StringExt.EMPTY;

    if (isStdIn) {
      text = stdin.readAsStringSync(endByte: StringExt.EOT_CODE);
    }
    else {
      var inpFile = File(inpFilePath);

      if (!inpFile.existsSync()) {
        throw Exception('No input file found: "${inpFilePath}"');
      }

      text = (inpFile.readAsStringSync() ?? StringExt.EMPTY);
    }

    if (canExpandEnv) {
      text = text.expandEnvironmentVariables();
    }

    for (; ;) {
      map.forEach((k, v) {
        text = text.replaceAll(k, v);
      });

      var isDone = true;

      map.forEach((k, v) {
        if (text.contains(k)) {
          isDone = false;
        }
      });

      if (isDone) {
        break;
      }
    }

    if (Log.isUltimate()) {
      Log.debug(text);
    }

    if (isStdOut) {
      Log.out(text);
      return null;
    }
    else {
      var outDir = Directory(outDirName);

      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      var tmpFile = File(tmpFilePath);

      if (tmpFile.existsSync()) {
        tmpFile.deleteSync();
      }

      tmpFile = File(tmpFilePath);
      tmpFile.writeAsStringSync(text);

      return (isExpandInpOnly ? null : tmpFile);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void expandMap(Map<String, String> map) {
    map.forEach((k, v) {
      map[k] = Config.getValue(map, k, canExpand: true);
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getActualInpFilePath() {
    if (isStdIn || isExpandInpOnly || !canExpandInp) {
      return inpFilePath;
    }
    else {
      var tmpFileName = (path.basenameWithoutExtension(outFilePath) + FILE_TYPE_TMP + path.extension(inpFilePath));

      return path.join(outDirName, tmpFileName);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}