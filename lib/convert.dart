import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
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

      if (StringExt.isNullOrBlank(inpFilePath)) {
        throw Exception('Undefined input for\n\n${map.toString()}');
      }

      var outFilePath = Config.getValue(map, Config.PARAM_NAME_OUT, canExpand: true);

      if (StringExt.isNullOrBlank(outFilePath)) {
        throw Exception('Undefined output for\n\n${map.toString()}');
      }

      inpFilePath = path.join(curDirName, inpFilePath).getFullPath();

      isExpandInpOnly = (command == Config.CMD_EXPAND);
      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);

      var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

      for (inpFilePath in inpFilePaths) {
        var inpBaseName = path.basename(inpFilePath);

        outFilePath = outFilePath
            .replaceAll(Config.PARAM_NAME_INP_DIR, path.dirname(inpFilePath))
            .replaceAll(Config.PARAM_NAME_INP_NAME, path.basenameWithoutExtension(inpBaseName))
            .replaceAll(Config.PARAM_NAME_INP_EXT, path.extension(inpBaseName));

        outFilePath = path.join(curDirName, outFilePath).getFullPath();

        outDirName = (isStdOut ? StringExt.EMPTY : path.dirname(outFilePath));

        if (isStdOut && !isExpandInpOnly) {
          throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
        }

        if (await execFile(command, inpFilePath, outFilePath, map)) {
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
    var inpFile = (isStdIn ? null : File(inpFilePath));

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception('Input file is not found: "${inpFilePath}"');
    }

    var tmpFilePath = (isExpandInpOnly || !canExpandInp ? null : getActualInpFilePath(inpFilePath, outFilePath));

    var cmdTemplateEx = cmdTemplate;

    if (isExpandInpOnly) {
      cmdTemplateEx += ' "${Config.PARAM_NAME_INP}" "${Config.PARAM_NAME_OUT}"';
    }

    var command = cmdTemplateEx
        .replaceAll(Config.PARAM_NAME_OUT, outFilePath)
        .replaceAll(Config.PARAM_NAME_INP, inpFilePath);

    if (commands.contains(command)) {
      return false;
    }

    commands.add(command);

    var outFile = File(outFilePath);

    if (!Options.isForced && !isStdIn && !isStdOut) {
      var isChanged = (outFile.compareLastModifiedTo(inpFile, isCoarse: true) < 0);

      if (!isChanged) {
        isChanged = (outFile.compareLastModifiedToInMicrosecondsSinceEpoch(Config.lastModifiedInMicrosecondsSinceEpoch) < 0);
      }

      if (!isChanged) {
        Log.information('Unchanged: "${outFilePath}"');
        return false;
      }
    }

    if (!isStdOut && outFile.existsSync()) {
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
    if (isStdIn || isExpandInpOnly || !canExpandInp) {
      return inpFilePath;
    }
    else if (!isStdOut) {
      var tmpFileName = (path.basenameWithoutExtension(outFilePath) + FILE_TYPE_TMP + path.extension(inpFilePath));
      var tmpDirName = path.dirname(outFilePath);

      return path.join(tmpDirName, tmpFileName);
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
      return [];
    }

    var filePathTrim = filePath.trim();

    var lst = <String>[];

    if (filePath == StringExt.STDIN_PATH) {
      lst.add(filePath);
    }
    else {
      var parentDirName = path.dirname(filePathTrim);
      var hasParentDir = !StringExt.isNullOrBlank(parentDirName);

      if (!path.isAbsolute(filePathTrim)) {
        filePathTrim = path.join(curDirName, filePathTrim);
        parentDirName = path.dirname(filePathTrim);
      }

      var dir = Directory(filePathTrim);
      var pattern = path.basename(filePathTrim);

      if (pattern.containsWildcards()) {
        if (hasParentDir) {
          dir = Directory(parentDirName);
        }

        lst = dir.pathListSync(
            pattern: pattern,
            checkExists: false,
            recursive: hasParentDir,
            takeDirs: false,
            takeFiles: true
        );
      }
      else if (dir.existsSync()) {
        lst = dir.pathListSync(
            pattern: null,
            checkExists: false,
            recursive: true,
            takeDirs: false,
            takeFiles: true
        );
      }
      else {
        var file = File(filePathTrim);

        if (file.existsSync()) {
          lst = [file.path];
        }
      }
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: ${filePath}');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

}