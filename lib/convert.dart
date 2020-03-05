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
  static String height;
  static String inpFilePath;
  static String outDirName;
  static String outFilePath;
  static String resizePattern;
  static String tmpFilePath;
  static String width;

  //////////////////////////////////////////////////////////////////////////////

  static Future<File> resizeInpFile(Map<String, String> map) async {
    var tmpFileName = (basenameWithoutExtension(inpFilePath) + FILE_TYPE_TMP + extension(inpFilePath));
    tmpFilePath = join(outDirName, tmpFileName);

    var resizeRE = RegExp(resizePattern, caseSensitive: true);

    var inpFile = new File(inpFilePath);

    if (!(await inpFile.exists())) {
      throw new Exception('No input file found: "${inpFilePath}"');
    }

    var text = await inpFile.readAsString();

    map.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    var outDir = Directory(outDirName);

    if (!(await outDir.exists())) {
      await outDir.create(recursive: true);
    }

    var tmpFile = new File(tmpFilePath);

    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    tmpFile = new File(tmpFilePath);
    await tmpFile.writeAsString(text);

    return tmpFile;
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future exec(List<String> args) async {
    var listOfMaps = await Config.exec(args);

    for (var map in listOfMaps) {
      command = Config.getParamValue(map, Config.PARAM_NAME_COMMAND);
      height = Config.getParamValue(map, Config.PARAM_NAME_HEIGHT);
      inpFilePath = Config.getParamValue(map, Config.PARAM_NAME_INPUT);
      outFilePath = Config.getParamValue(map, Config.PARAM_NAME_OUTPUT);
      outDirName = dirname(outFilePath);
      width = Config.getParamValue(map, Config.PARAM_NAME_WIDTH);

      print(relative(outFilePath));

      resizePattern = (Config.getParamValue(map, Config.PARAM_NAME_RESIZE) ?? StringExt.EMPTY);

      File tmpFile;
      var inpFilePathEx = inpFilePath;

      if (!StringExt.isNullOrEmpty(resizePattern)) {
        tmpFile = await resizeInpFile(map);
        inpFilePathEx = tmpFilePath;
      }

      command = command.replaceAll(Config.PARAM_NAME_INPUT, inpFilePathEx);

      var exitCodes = (await Shell(verbose: Config.isVerbose).run(command));

      if (tmpFile != null) {
        await tmpFile.delete();
      }

      if (exitCodes.first.exitCode != 0) {
        throw new Exception('Command failed:\n\n${command}\n\n');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static getTemporaryPath(String path, String extension) async {
    return (withoutExtension(path) + FILE_TYPE_TMP + extension);
  }

  //////////////////////////////////////////////////////////////////////////////

}