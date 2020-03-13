import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:process_run/shell_run.dart';

import 'config.dart';
import 'log.dart';
import 'options.dart';
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
      outFilePath = Config.getParamValue(map, Config.PARAM_NAME_OUTPUT);
      outDirName = path.dirname(outFilePath);

      if (Options.isListOnly || isExpandInpOnly) {
        Log.out(commandToDisplayString(command));
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

      command = command.replaceAll(Config.PARAM_NAME_INPUT, inpFilePathEx);
      var exitCodes = (await Shell(verbose: (Log.level > Log.LEVEL_OUT)).run(command));

      if (exitCodes.first.exitCode != 0) {
        throw Exception('Command failed:\n\n${commandToDisplayString(command)}\n\n');
      }

      tmpFile.deleteSync();
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static File expandInpFile(Map<String, String> map) {
    var inpFile = File(inpFilePath);

    if (!inpFile.existsSync()) {
      throw Exception('No input file found: "${inpFilePath}"');
    }

    var text = (inpFile.readAsStringSync() ?? StringExt.EMPTY);

    if (canExpandEnv) {
      text = text.expandEnvironmentVariables();
    }

    map.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    var outDir = Directory(outDirName);

    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    if (isExpandInpOnly) {
      tmpFilePath = outFilePath;
    }
    else {
      var tmpFileName = (path.basenameWithoutExtension(inpFilePath) + FILE_TYPE_TMP + path.extension(inpFilePath));
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

  //////////////////////////////////////////////////////////////////////////////

}