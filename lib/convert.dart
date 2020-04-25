import 'dart:async';
import 'dart:io';

import 'package:doul/ext/glob.dart';
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

  Config _config;
  bool canExpandEnv;
  bool canExpandInp;
  bool isExpandInpOnly;
  bool isStdIn;
  bool isStdOut;
  String outDirName;
  List<String> commands;

  //////////////////////////////////////////////////////////////////////////////

  Future exec(List<String> args) async {
    _config = Config();
    var maps = _config.exec(args);
    commands = [];

    var isProcessed = false;
    var mapPrev = <String, String>{};

    for (var mapOrig in maps) {
      var curDirName = getCurDirName(mapOrig);

      var inpFilePath = (getValue(mapOrig, _config.paramNameInp, mapPrev: mapPrev, canExpand: true) ?? StringExt.EMPTY);
      var hasInpFile = !StringExt.isNullOrBlank(inpFilePath);

      if (hasInpFile) {
        inpFilePath = Path.join(curDirName, inpFilePath).getFullPath();
      }

      var subStart = (hasInpFile ? (inpFilePath.length - Path.basename(inpFilePath).length) : 0);
      var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

      for (var inpFilePathEx in inpFilePaths) {
        var map = expandMap(mapOrig, inpFilePathEx);

        canExpandEnv = StringExt.parseBool(getValue(map, _config.paramNameExpEnv, canExpand: false));
        canExpandInp = StringExt.parseBool(getValue(map, _config.paramNameExpInp, canExpand: false));
        var command = getValue(map, _config.paramNameCmd, canExpand: false);

        if (!StringExt.isNullOrBlank(curDirName)) {
          Log.debug('Setting current directory to: "${curDirName}"');
          Directory.current = curDirName;
        }

        if (StringExt.isNullOrBlank(command)) {
          throw Exception('Undefined command for\n\n${map.toString()}');
        }

        var outFilePath = (getValue(map, _config.paramNameOut, mapPrev: mapPrev, canExpand: true) ?? StringExt.EMPTY);
        var hasOutFile = !StringExt.isNullOrBlank(outFilePath);

        isExpandInpOnly = (command == Config.CMD_EXPAND);
        isStdIn = (inpFilePath == StringExt.STDIN_PATH);
        isStdOut = (outFilePath == StringExt.STDOUT_PATH);

        var outFilePathEx = (hasOutFile ? outFilePath : inpFilePathEx);

        if (hasOutFile && hasInpFile) {
          var dirName = Path.dirname(inpFilePathEx);
          var inpSubDirName = (dirName.length <= subStart ? StringExt.EMPTY : dirName.substring(subStart));
          var inpFullName = Path.basename(inpFilePathEx);
          var inpName = Path.basenameWithoutExtension(inpFullName);
          var inpExt = Path.extension(inpFullName);
          var inpSubPath = inpFilePathEx.substring(subStart);

          outFilePathEx = outFilePathEx
            .replaceAll(_config.paramNameInpDir, dirName)
            .replaceAll(_config.paramNameInpName, inpName)
            .replaceAll(_config.paramNameInpExt, inpExt)
            .replaceAll(_config.paramNameInpPath, inpFilePathEx)
            .replaceAll(_config.paramNameInpSubDir, inpSubDirName)
            .replaceAll(_config.paramNameInpSubPath, inpSubPath)
            .replaceAll(_config.paramNameInpNameExt, inpFullName)
          ;

          outFilePathEx = Path.join(curDirName, outFilePathEx).getFullPath();
        }

        outDirName = (isStdOut ? StringExt.EMPTY : Path.dirname(outFilePathEx));

        if (isStdOut && !isExpandInpOnly) {
          throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
        }

        if (await execFile(command, inpFilePathEx, outFilePathEx, map)) {
          isProcessed = true;
        }
      }

      mapOrig.forEach((k, v) {
        mapPrev[k] = v;
      });
    }

    if (!isStdOut && !isProcessed) {
      Log.outInfo('All output files are up to date.');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Future<bool> execFile(String cmdTemplate, String inpFilePath, String outFilePath, Map<String, String> map) async {
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

      cmdTemplateEx += ' "${_config.paramNameInp}" "${_config.paramNameOut}"';
    }

    var command = cmdTemplateEx
        .replaceAll(_config.paramNameOut, outFilePath)
        .replaceAll(_config.paramNameInp, inpFilePath);

    if (commands.contains(command)) {
      return false;
    }

    commands.add(command);

    var outFile = (hasOutFile ? File(outFilePath) : null);

    if (!Options.isForced && (inpFilePath != outFilePath)) {
      var isChanged = (outFile.compareLastModifiedTo(inpFile, isCoarse: true) < 0);

      if (!isChanged) {
        isChanged = (outFile.compareLastModifiedMcsecTo(_config.lastModifiedMcsec) < 0);
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
        .replaceAll(_config.paramNameOut, outFilePath)
        .replaceAll(_config.paramNameInp, tmpFilePath);
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

  File expandInpFile(File inpFile, String outFilePath, String tmpFilePath, Map<String, String> map) {
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

  Map<String, String> expandMap(Map<String, String> map, String inpFilePath) {
    var newMap = <String, String>{};
    newMap.addAll(map);

    newMap.forEach((k, v) {
      if (k == _config.paramNameInp) {
        newMap[k] = inpFilePath;
      }
      else {
        newMap[k] = getValue(map, k, canExpand: true);

        if (_config.isParamWithPath(k)) {
          newMap[k] = newMap[k].getFullPath();
        }
      }
    });

    return newMap;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getActualInpFilePath(String inpFilePath, String outFilePath) {
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

  String getCurDirName(Map<String, String> map) {
    var curDirName = (getValue(map, _config.paramNameCurDir, canExpand: false) ?? StringExt.EMPTY);
    curDirName = curDirName.getFullPath();

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> getInpFilePaths(String filePath, String curDirName) {
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
        filePathTrim = Path.join(curDirName, filePathTrim).getFullPath();
      }

      var dir = Directory(filePathTrim);

      if (dir.existsSync()) {
        lst = dir.pathListSync(null, checkExists: false);
      }
      else {
        dir = Directory(GlobExt.getDirectoryName(filePathTrim));
        lst = dir.pathListSync(filePathTrim, checkExists: false);
      }
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: ${filePath}');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getValue(Map<String, String> map, String key, {Map<String, String> mapPrev, bool canExpand}) {
    //var isCmd = (key == PARAM_NAME_CMD);

    if (map.containsKey(key)) {
      var value = map[key];

      if ((canExpand ?? false) && (value != null)) {
        for (var oldValue = null; (oldValue != value); ) {
          oldValue = value;

          map.forEach((k, v) {
            if (k != key) {
              if ((k != _config.paramNameInp) && (k != _config.paramNameOut)) {
                value = value.replaceAll(k, v);
              }
            }
          });
        }
      }

      if (value.contains(key) && (mapPrev != null) && mapPrev.containsKey(key)) {
        value = value.replaceAll(key, mapPrev[key]);
      }

      return value;
    }
    else {
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}