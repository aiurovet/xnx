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

  static final String FILE_TYPE_TMP = '.tmp';

  //////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////

  static String command;
  static String inpFilePath;
  static String outDirName;
  static String outFilePath;
  static bool canExpandEnv;
  static bool canExpandInp;
  static String tmpFilePath;

  //////////////////////////////////////////////////////////////////////////////

  static Future exec(List<String> args) async {
    var listOfMaps = await Config.exec(args);

    for (var map in listOfMaps) {
      canExpandEnv = StringExt.parseBool(Config.getParamValue(map, Config.PARAM_NAME_EXPAND_ENV));
      canExpandInp = StringExt.parseBool(Config.getParamValue(map, Config.PARAM_NAME_EXPAND_INP));
      command = Config.getParamValue(map, Config.PARAM_NAME_COMMAND);
      inpFilePath = Config.getParamValue(map, Config.PARAM_NAME_INPUT);
      outFilePath = Config.getParamValue(map, Config.PARAM_NAME_OUTPUT);
      outDirName = path.dirname(outFilePath);

      if (Options.isListOnly) {
        command = command.replaceAll(Config.PARAM_NAME_INPUT, inpFilePath);
        Log.out(command);
        continue;
      }

      Log.information(path.relative(outFilePath));

      var outFile = File(outFilePath);

      if (await outFile.exists()) {
        await outFile.delete();
      }

      var tmpFile = (canExpandInp ? await expandInpFile(map) : null);

      if (tmpFile == null) {
        continue;
      }

      var inpFilePathEx = (canExpandInp ? tmpFilePath : inpFilePath);

      command = command.replaceAll(Config.PARAM_NAME_INPUT, inpFilePathEx);
      var exitCodes = (await Shell(verbose: (Log.level > Log.LEVEL_OUT)).run(command));

      if (exitCodes.first.exitCode != 0) {
        throw Exception('Command failed:\n\n${command}\n\n');
      }

      await tmpFile.delete();
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future<File> expandInpFile(Map<String, String> map) async {
    var inpFile = File(inpFilePath);

    if (!(await inpFile.exists())) {
      throw Exception('No input file found: "${inpFilePath}"');
    }

    var text = await inpFile.readAsString();

    if (canExpandEnv) {
      text = StringExt.expandEnvironmentVariables(text);
    }

    map.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    var outDir = Directory(outDirName);

    if (!(await outDir.exists())) {
      await outDir.create(recursive: true);
    }

    var isExpandInpOnly = (command == Config.CMD_EXPAND);

    if (isExpandInpOnly) {
      tmpFilePath = outFilePath;
    }
    else {
      var tmpFileName = (path.basenameWithoutExtension(inpFilePath) + FILE_TYPE_TMP + path.extension(inpFilePath));
      tmpFilePath = path.join(outDirName, tmpFileName);
    }

    var tmpFile = File(tmpFilePath);

    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    tmpFile = File(tmpFilePath);
    await tmpFile.writeAsString(text);

    return (isExpandInpOnly ? null : tmpFile);
  }

  //////////////////////////////////////////////////////////////////////////////

}