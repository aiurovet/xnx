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

  //////////////////////////////////////////////////////////////////////////////

  static String commandToDisplayString(String cmd) {
    if (cmd == null) {
      return StringExt.EMPTY;
    }
    else if (isExpandInpOnly) {
      return cmd + ': "${outFilePath}"';
    }
    else {
      return cmd.replaceAll(Config.PARAM_NAME_INPUT, inpFilePath);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future exec(List<String> args) async {
    var listOfMaps = Config.exec(args);

    for (var map in listOfMaps) {
      canExpandEnv = StringExt.parseBool(Config.getParamValue(map, Config.PARAM_NAME_EXPAND_ENV));
      canExpandInp = StringExt.parseBool(Config.getParamValue(map, Config.PARAM_NAME_EXPAND_INP));
      command = Config.getParamValue(map, Config.PARAM_NAME_COMMAND);
      isExpandInpOnly = (command == Config.CMD_EXPAND);
      inpFilePath = Config.getParamValue(map, Config.PARAM_NAME_INPUT);
      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      outFilePath = Config.getParamValue(map, Config.PARAM_NAME_OUTPUT);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);
      outDirName = (isStdOut ? StringExt.EMPTY : path.dirname(outFilePath));

      if (isStdOut && !isExpandInpOnly) {
        throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
      }

      var isVerbose = Log.isDetailed();

      if (Options.isListOnly || isExpandInpOnly || !isVerbose) {
        Log.outInfo(commandToDisplayString(command));
      }

      if (Options.isListOnly) {
        continue;
      }

      Log.information(path.relative(outFilePath));

      var outFile = File(outFilePath);

      if (outFile.existsSync()) {
        outFile.deleteSync();
      }

      var tmpFile = (canExpandInp ? expandInpFile(map) : null);

      if (tmpFile == null) {
        continue;
      }

      var inpFilePathEx = (canExpandInp ? tmpFilePath : inpFilePath);

      if (canExpandInp) {
        Log.outInfo('...temporary file: "${inpFilePathEx}"');
      }

      if (isStdIn) {
        inpFilePathEx = StringExt.EMPTY;
      }

      command = command.replaceAll(inpFilePath, inpFilePathEx);
      var exitCodes = (await Shell(verbose: isVerbose).run(command));

      if (exitCodes.first.exitCode != 0) {
        throw Exception('Command failed:\n\n${commandToDisplayString(command)}\n\n');
      }

      tmpFile.deleteSync();
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static File expandInpFile(Map<String, String> map) {
    var text = StringExt.EMPTY;

    if (isStdIn) {
      text = stdin.readAllSync(endByte: StringExt.EOT_CODE);
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

    map.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

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

      if (isExpandInpOnly) {
        tmpFilePath = outFilePath;
      }
      else {
        var tmpFileName = (path.basenameWithoutExtension(outFilePath) + FILE_TYPE_TMP + path.extension(inpFilePath));
        tmpFilePath = path.join(outDirName, tmpFileName);
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

}