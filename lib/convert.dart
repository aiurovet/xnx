import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as Path;
import 'package:process_run/shell_run.dart';

import 'config.dart';
import 'log.dart';
import 'options.dart';
import 'ext/directory.dart';
import 'ext/file.dart';
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
  static bool isExpandInpOnly;
  static bool isStdIn;
  static bool isStdOut;
  static String outDirName;
  static List<String> commands;

  //////////////////////////////////////////////////////////////////////////////

  static Future exec(List<String> args) async {
    var maps = Config.exec(args);
    commands = [];

    var isProcessed = false;

    for (var map in maps) {
      expandMap(map);

      canExpandEnv = StringExt.parseBool(Config.getValue(map, Config.PARAM_NAME_EXP_ENV, canExpand: false));
      canExpandInp = StringExt.parseBool(Config.getValue(map, Config.PARAM_NAME_EXP_INP, canExpand: false));
      var command = Config.getValue(map, Config.PARAM_NAME_CMD, canExpand: false);

      var curDirName = getCurDirName(map);

      if (!StringExt.isNullOrBlank(curDirName)) {
        Log.debug('Setting current directory to: "${curDirName}"');
        Directory.current = curDirName;
      }

      if (StringExt.isNullOrBlank(command)) {
        throw Exception('Undefined command for\n\n${map.toString()}');
      }

      var inpFilePath = Config.getValue(map, Config.PARAM_NAME_INP, canExpand: true);
      var hasInpFile = !StringExt.isNullOrBlank(inpFilePath);

      var outFilePath = Config.getValue(map, Config.PARAM_NAME_OUT, canExpand: true);
      var hasOutFile = !StringExt.isNullOrBlank(outFilePath);

      isExpandInpOnly = (command == Config.CMD_EXPAND);
      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);

      if (hasInpFile) {
        inpFilePath = Path.join(curDirName, inpFilePath).getFullPath();
      }

      var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

      for (inpFilePath in inpFilePaths) {
        var inpBaseName = Path.basename(inpFilePath);
        var outFilePathEx = (hasOutFile ? outFilePath : inpFilePath);

        if (hasOutFile && hasInpFile) {
          outFilePathEx = outFilePathEx
            .replaceAll(Config.PARAM_NAME_INP_DIR, Path.dirname(inpFilePath)).replaceAll(Config.PARAM_NAME_INP_NAME, Path.basenameWithoutExtension(inpBaseName))
            .replaceAll(Config.PARAM_NAME_INP_EXT, Path.extension(inpBaseName))
            .replaceAll(Config.PARAM_NAME_INP_FULL, inpFilePath)
            .replaceAll(Config.PARAM_NAME_INP_NAME_EXT, inpBaseName)
          ;

          outFilePathEx = Path.join(curDirName, outFilePathEx).getFullPath();
        }

        outDirName = (isStdOut ? StringExt.EMPTY : Path.dirname(outFilePathEx));

        if (isStdOut && !isExpandInpOnly) {
          throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
        }

        if (await execFile(command, inpFilePath, outFilePathEx, map)) {
          isProcessed = true;
        }
      }
    }

    if (!isStdOut && !isProcessed) {
      Log.outInfo('All output files are up to date.');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future<bool> execFile(String cmdTemplate, String inpFilePath, String outFilePath, Map<String, String> map) async {
    var hasInpFile = (!isStdIn && !StringExt.isNullOrBlank(inpFilePath));
    var hasOutFile = (!isStdOut && !StringExt.isNullOrBlank(outFilePath));

    var inpFile = (hasInpFile ? File(inpFilePath) : null);

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception('Input file is not found: "${inpFilePath}"');
    }

    String tmpFilePath;

    if (canExpandInp && (!isExpandInpOnly || (hasInpFile && hasOutFile && (inpFilePath == outFilePath)))) {
      tmpFilePath = getActualInpFilePath(inpFilePath, outFilePath);
    }

    var cmdTemplateEx = cmdTemplate;

    if (isExpandInpOnly) {
      if (!hasInpFile) {
        throw Exception('Input file to expand is not defined');
      }

      cmdTemplateEx += ' "${Config.PARAM_NAME_INP}" "${Config.PARAM_NAME_OUT}"';
    }

    var command = cmdTemplateEx
        .replaceAll(Config.PARAM_NAME_OUT, outFilePath)
        .replaceAll(Config.PARAM_NAME_INP, inpFilePath);

    if (commands.contains(command)) {
      return false;
    }

    commands.add(command);

    var outFile = (hasOutFile ? File(outFilePath) : null);

    if (!Options.isForced && (inpFilePath != outFilePath)) {
      var isChanged = (outFile.compareLastModifiedTo(inpFile, isCoarse: true) < 0);

      if (!isChanged) {
        isChanged = (outFile.compareLastModifiedToInMicrosecondsSinceEpoch(Config.lastModifiedInMicrosecondsSinceEpoch) < 0);
      }

      if (!isChanged) {
        Log.information('Unchanged: "${outFilePath}"');
        return false;
      }
    }

    if (!isStdOut && (inpFilePath != outFilePath) && (outFile != null) && outFile.existsSync()) {
      outFile.deleteSync();
    }

    if (canExpandInp) {
      expandInpFile(inpFile, outFilePath, tmpFilePath, map);
    }

    var isVerbose = Log.isDetailed();

    if (Options.isListOnly || isExpandInpOnly || !isVerbose) {
      Log.outInfo(command);
    }

    if (Options.isListOnly || isExpandInpOnly) {
      return true;
    }

    if (tmpFilePath != null) {
      command = cmdTemplateEx
        .replaceAll(Config.PARAM_NAME_OUT, outFilePath)
        .replaceAll(Config.PARAM_NAME_INP, tmpFilePath);
    }

    var exitCodes = await Shell(verbose: isVerbose).run(command);

    if (exitCodes.any((x) => (x.exitCode != 0))) {
      throw Exception('Command failed${isVerbose ? StringExt.EMPTY : '\n\n${command}\n\n'}');
    }

    if (tmpFilePath != null) {
      var tmpFile = File(tmpFilePath);

      if (tmpFile.existsSync()) {
        tmpFile.deleteSync();
      }
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  static File expandInpFile(File inpFile, String outFilePath, String tmpFilePath, Map<String, String> map) {
    var text = StringExt.EMPTY;

    if (inpFile == null) {
      text = stdin.readAsStringSync(endByte: StringExt.EOT_CODE);
    }
    else {
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

      var tmpFile = File(tmpFilePath ?? outFilePath);

      if (tmpFile.existsSync()) {
        tmpFile.deleteSync();
      }

      tmpFile.writeAsStringSync(text);

      if (inpFile.path == outFilePath) {
        tmpFile.renameSync(outFilePath);
      }

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

  static String getActualInpFilePath(String inpFilePath, String outFilePath) {
    if (isStdIn || (isExpandInpOnly && (inpFilePath != outFilePath)) || !canExpandInp) {
      return inpFilePath;
    }
    else if (!isStdOut) {
      if (StringExt.isNullOrBlank(outFilePath)) {
        return StringExt.EMPTY;
      }
      else {
        var tmpFileName = (Path.basenameWithoutExtension(outFilePath) +
            FILE_TYPE_TMP + Path.extension(inpFilePath));
        var tmpDirName = Path.dirname(outFilePath);

        return Path.join(tmpDirName, tmpFileName);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getCurDirName(Map<String, String> map) {
    var curDirName = (Config.getValue(map, Config.PARAM_NAME_CUR_DIR, canExpand: false) ?? StringExt.EMPTY);
    curDirName = curDirName.getFullPath();

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getInpFilePaths(String filePath, String curDirName) {
    if (StringExt.isNullOrBlank(filePath)) {
      return [ filePath ]; // ensure at least one pass in a loop
    }

    var filePathTrim = filePath.trim();

    var lst = <String>[];

    if (filePath == StringExt.STDIN_PATH) {
      lst.add(filePath);
    }
    else {
      if (!Path.isAbsolute(filePathTrim)) {
        filePathTrim = Path.join(curDirName, filePathTrim);
      }

      var dir = Directory(filePathTrim);

      if (dir.existsSync()) {
        lst = dir.pathListSync(null, checkExists: false);
      }
      else {
        var pattern = Path.basename(filePathTrim);

        dir = Directory(Path.dirname(filePathTrim));
        lst = dir.pathListSync(pattern, checkExists: false);
      }
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: ${filePath}');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

}