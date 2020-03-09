import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell_run.dart';

import 'config.dart';
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
      outDirName = dirname(outFilePath);

      print(relative(outFilePath));

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
      var exitCodes = (await Shell(verbose: Config.isVerbose).run(command));

      if (exitCodes.first.exitCode != 0) {
        throw new Exception('Command failed:\n\n${command}\n\n');
      }

      await tmpFile.delete();
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future<File> expandInpFile(Map<String, String> map) async {
    var inpFile = new File(inpFilePath);

    if (!(await inpFile.exists())) {
      throw new Exception('No input file found: "${inpFilePath}"');
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

    var isExpandInpOnly = StringExt.isNullOrBlank(command);

    if (isExpandInpOnly) {
      tmpFilePath = outFilePath;
    }
    else {
      var tmpFileName = (basenameWithoutExtension(inpFilePath) + FILE_TYPE_TMP + extension(inpFilePath));
      tmpFilePath = join(outDirName, tmpFileName);
    }

    var tmpFile = new File(tmpFilePath);

    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    tmpFile = new File(tmpFilePath);
    await tmpFile.writeAsString(text);

    return (isExpandInpOnly ? null : tmpFile);
  }

  //////////////////////////////////////////////////////////////////////////////

  static getTemporaryPath(String path, String extension) async {
    return (withoutExtension(path) + FILE_TYPE_TMP + extension);
  }

  //////////////////////////////////////////////////////////////////////////////

}