import 'dart:cli';
import 'dart:convert';
import 'dart:io';

import 'package:doul/config_file_loader.dart';
import 'package:doul/config.dart';
import 'package:doul/doul.dart';
import 'package:doul/ext/glob.dart';
import 'package:doul/file_oper.dart';
import 'package:doul/log.dart';
import 'package:doul/options.dart';
import 'package:doul/pack_oper.dart';
import 'package:doul/ext/directory.dart';
import 'package:doul/ext/file.dart';
import 'package:doul/ext/file_system_entity.dart';
import 'package:doul/ext/stdin.dart';
import 'package:doul/ext/string.dart';

import 'package:path/path.dart' as Path;
import 'package:process_run/shell_run.dart';

class Convert {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String FILE_TYPE_TMP = '.tmp';

  //////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////

  bool canExpandContent;
  RegExp detectPathsRE;
  bool hasStop;
  bool isExpandContentOnly;
  bool isStdIn;
  bool isStdOut;
  String curDirName;
  String outDirName;
  String startCmd;

  Config _config;
  List<String> _inpParamNames;
  Options _options;

  //////////////////////////////////////////////////////////////////////////////

  void exec(List<String> args) {
    startCmd = FileExt.getStartCommand();

    _config = Config();
    var maps = _config.exec(args);
    _options = _config.options;
    PackOper.compression = _options.compression;
    var plainArgs = _options.plainArgs;

    if ((maps?.isEmpty ?? true) && _options.isCmd) {
      execBuiltin(_options.plainArgs);
      return;
    }

    _inpParamNames = _config.getInpParamNames();

    for (; (maps?.isNotEmpty ?? false);) {
      var isProcessed = false;

      if ((plainArgs?.length ?? 0) <= 0) {
        plainArgs = [ null ];
      }

      hasStop = false;

      for (var i = 0, n = plainArgs.length; i < n; i++) {
        var mapPrev = <String, String>{};
        var plainArg = plainArgs[i];

        for (var mapOrig in maps) {
          if (execMap(plainArg, mapOrig, mapPrev)) {
            isProcessed = true;
          }
          if (hasStop) {
            return;
          }
        }
      }

      if ((isStdOut != null) && !isStdOut && !isProcessed) {
        Log.outInfo('All output files are up to date.');
      }

      maps = _config.exec();

      if (maps?.isNotEmpty ?? false) {
        Log.debug('\nRun #${_config.runNo} found\n');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execBuiltin(List<String> args, {bool isSilent}) {
    var argCount = (args?.length ?? 0);

    isSilent ??= Log.isSilent;

    if (argCount <= 0) {
      throw Exception('No argument specified for the built-in command');
    }

    var end = (args.length - 1);
    var arg1 = (end >= 0 ? args[0] : null);
    var arg2 = (end >= 1 ? args[1] : null);

    final isCompress = _options.isCmdCompress;
    final isDecompress = _options.isCmdDecompress;
    final isMove = _options.isCmdMove;

    if (isCompress || isDecompress) {
      final archPath = (isDecompress ? arg1 : (end >= 0 ? args[end] : 0));
      final archType = PackOper.getPackType(_options.archType, archPath);
      final isTar = PackOper.isPackTypeTar(archType);

      if (isTar || (archType == PackType.Zip)) {
        if (isCompress) {
          PackOper.archiveSync(fromPaths: args, end: end, packType: archType, isMove: isMove, isSilent: isSilent);
        }
        else {
          PackOper.unarchiveSync(archType, arg1, arg2, isMove: isMove, isSilent: isSilent);
        }
      }
      else {
        if (isCompress) {
          PackOper.compressSync(archType, arg1, toPath: arg2, isMove: true, isSilent: isSilent);
        }
        else {
          PackOper.uncompressSync(archType, arg1, toPath: arg2, isMove: true, isSilent: isSilent);
        }
      }
    }
    else {
      if (_options.isCmdCopy || _options.isCmdCopyNewer) {
        FileOper.xferSync(fromPaths: args, end: end, isMove: false, isNewerOnly: _options.isCmdCopyNewer, isSilent: isSilent);
      }
      else if (_options.isCmdMove || _options.isCmdMoveNewer) {
        FileOper.xferSync(fromPaths: args, end: end, isMove: true, isNewerOnly: _options.isCmdMoveNewer, isSilent: isSilent);
      }
      else if (_options.isCmdCreateDir) {
        FileOper.createDirSync(dirNames: args, isSilent: isSilent);
      }
      else if (_options.isCmdDelete) {
        FileOper.deleteSync(paths: args, isSilent: isSilent);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execMap(String plainArg, Map<String, String> mapOrig, Map<String, String> mapPrev) {
    if (mapOrig.containsKey(_config.paramNameStop)) {
      hasStop = true;
      return true;
    }
    if (mapOrig.containsKey(_config.paramNameNext)) {
      return true;
    }

    var isProcessed = false;
    var isKeyArgsFound = false;
    var mapCurr = <String, String>{};
    var keyArgs = ConfigFileLoader.ALL_ARGS;

    mapOrig.forEach((k, v) {
      if ((v != null) && v.contains(keyArgs)) {
        isKeyArgsFound = true;
      }
    });

    if (StringExt.isNullOrBlank(plainArg)) {
      if (isKeyArgsFound) {
        return false;
      }
    }
    else {
      mapOrig[keyArgs] = plainArg;
    }

    curDirName = getCurDirName(mapOrig);

    var inpFilePath = (getValue(mapOrig, key: _config.paramNameInp, mapPrev: mapPrev, canReplace: true) ?? StringExt.EMPTY);
    var hasInpFile = !StringExt.isNullOrBlank(inpFilePath);

    if (hasInpFile) {
      if (!Path.isAbsolute(inpFilePath)) {
        inpFilePath = Path.join(curDirName, inpFilePath);
      }

      if (inpFilePath.contains(_config.paramNameInp) ||
          inpFilePath.contains(_config.paramNameInpDir) ||
          inpFilePath.contains(_config.paramNameInpExt) ||
          inpFilePath.contains(_config.paramNameInpName) ||
          inpFilePath.contains(_config.paramNameInpNameExt) ||
          inpFilePath.contains(_config.paramNameInpPath) ||
          inpFilePath.contains(_config.paramNameInpSubDir) ||
          inpFilePath.contains(_config.paramNameInpSubPath)) {
        //throw Exception('Circular reference is not allowed: input file path is "${inpFilePath}"');
        inpFilePath = expandInpNames(inpFilePath, mapPrev);
      }

      inpFilePath = inpFilePath.getFullPath();
    }

    var subStart = (hasInpFile ? (inpFilePath.length - Path.basename(inpFilePath).length) : 0);
    var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

    for (var inpFilePathEx in inpFilePaths) {
      inpFilePathEx = inpFilePathEx.adjustPath();
      mapCurr.addAll(expandMap(mapOrig, curDirName, inpFilePathEx));

      mapPrev.forEach((k, v) {
        if (!mapCurr.containsKey(k)) {
          mapCurr[k] = v;
        }
      });

      var detectPathsPattern = getValue(mapCurr, key: _config.paramNameDetectPaths, canReplace: true);

      if (StringExt.isNullOrBlank(detectPathsPattern)) {
        detectPathsRE = null;
      }
      else {
        detectPathsRE = RegExp(detectPathsPattern, caseSensitive: false);
      }

      var command = getValue(mapCurr, key: _config.paramNameCmd, canReplace: false);

      isExpandContentOnly = Config.RE_CMD_EXPAND.hasMatch(command);
      canExpandContent = (isExpandContentOnly || StringExt.parseBool(getValue(mapCurr, key: _config.paramNameCanExpandContent, canReplace: false)));

      if (!StringExt.isNullOrBlank(curDirName)) {
        Log.debug('Setting current directory to: "${curDirName}"');
        Directory.current = curDirName;
      }

      if (StringExt.isNullOrBlank(command)) {
        if (_config.options.isListOnly) {
          Log.out(jsonEncode(mapCurr) + (_config.options.isAppendSep ? ConfigFileLoader.RECORD_SEP : StringExt.EMPTY));
        }
        return true;
      }

      var outFilePath = (getValue(mapCurr, key: _config.paramNameOut, mapPrev: mapPrev, canReplace: true) ?? StringExt.EMPTY).adjustPath();
      var hasOutFile = outFilePath.isNotEmpty;

      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);

      var outFilePathEx = (hasOutFile ? outFilePath : inpFilePathEx);

      if (hasInpFile) {
        var dirName = Path.dirname(inpFilePathEx);
        var inpNameExt = Path.basename(inpFilePathEx);

        mapCurr[_config.paramNameInpDir] = dirName;
        mapCurr[_config.paramNameInpSubDir] = (dirName.length <= subStart ? StringExt.EMPTY : dirName.substring(subStart));
        mapCurr[_config.paramNameInpNameExt] = inpNameExt;
        mapCurr[_config.paramNameInpExt] = Path.extension(inpNameExt);
        mapCurr[_config.paramNameInpName] = Path.basenameWithoutExtension(inpNameExt);
        mapCurr[_config.paramNameInpPath] = inpFilePathEx;
        mapCurr[_config.paramNameInpSubPath] = inpFilePathEx.substring(subStart);
print("DBG: HERE");
        mapCurr[_config.paramNameThis] = startCmd;

        mapCurr.forEach((k, v) {
          if ((v != null) && (k != _config.paramNameCmd) && !_inpParamNames.contains(k)) {
            mapCurr[k] = expandInpNames(v, mapCurr);
          }
        });

        if (hasOutFile) {
          outFilePathEx = expandInpNames(outFilePathEx, mapCurr);
          outFilePathEx = Path.join(curDirName, outFilePathEx).getFullPath();
        }

        outFilePathEx = outFilePathEx.adjustPath();

        Log.debug('''

Input dir:       "${mapCurr[_config.paramNameInpDir]}"
Input sub-dir:   "${mapCurr[_config.paramNameInpSubDir]}"
Input name:      "${mapCurr[_config.paramNameInpName]}"
Input extension: "${mapCurr[_config.paramNameInpExt]}"
Input name-ext:  "${mapCurr[_config.paramNameInpNameExt]}"
Input path:      "${mapCurr[_config.paramNameInpPath]}"
Input sub-path:  "${mapCurr[_config.paramNameInpSubPath]}"
        ''');
      }

      outDirName = (isStdOut ? StringExt.EMPTY : Path.dirname(outFilePathEx));

      Log.debug('''

Output dir:  "${outDirName}"
Output path: "${outFilePathEx ?? StringExt.EMPTY}"
        ''');

      if (isStdOut && !isExpandContentOnly) {
        throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
      }

      var isOK = execFile(command, inpFilePathEx, outFilePathEx, mapCurr);

      if (isOK) {
        isProcessed = true;
      }
    }

    mapCurr.forEach((k, v) {
      mapPrev[k] = v;
    });

    return isProcessed;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execFile(String cmdTemplate, String inpFilePath, String outFilePath, Map<String, String> map) {
    var command = expandInpNames(cmdTemplate.replaceAll(_config.paramNameOut, outFilePath), map)
        .replaceAll(_config.paramNameCurDir, curDirName);

    if (isExpandContentOnly) {
      var cmdParts = command.splitCommandLine();
      var argCount = cmdParts.length - 1;

      if (argCount > 0) {
        outFilePath = cmdParts[argCount];
      }

      if (argCount > 1) {
        inpFilePath = cmdParts[1];
      }
    }

    var hasInpFile = (!isStdIn && !StringExt.isNullOrBlank(inpFilePath));

    if (isExpandContentOnly && !hasInpFile) {
      throw Exception('Input file is undefined for ${Config.CMD_EXPAND} operation');
    }

    var inpFile = (hasInpFile ? File(inpFilePath) : null);

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception('Input file is not found: "${inpFilePath}"');
    }

    var hasOutFile = (!isStdOut && !StringExt.isNullOrBlank(outFilePath) && !Directory(outFilePath).existsSync());

    String tmpFilePath;

    if (canExpandContent && (!isExpandContentOnly || (hasInpFile && hasOutFile && (inpFilePath == outFilePath)))) {
      tmpFilePath = getActualInpFilePath(inpFilePath, outFilePath);
    }

    Log.debug('Temp file path: "${tmpFilePath ?? StringExt.EMPTY}"');

    var outFile = (hasOutFile ? File(outFilePath) : null);

    if (!_options.isForced && (inpFilePath != outFilePath) && (outFile != null)) {
      var isChanged = (outFile.compareLastModifiedStampToSync(toFile: inpFile) < 0);

      if (!isChanged) {
        isChanged = (outFile.compareLastModifiedStampToSync(toLastModifiedStamp: _config.lastModifiedStamp) < 0);
      }

      if (!isChanged) {
        Log.information('Unchanged: "${outFilePath}"');
        return false;
      }
    }

    if (!isStdOut && (inpFilePath != outFilePath) && (outFile != null)) {
      outFile.deleteIfExistsSync();
    }

    if (canExpandContent) {
      expandInpContent(inpFile, outFilePath, tmpFilePath, map);
    }

    command = (getValue(map, value: command, canReplace: true) ?? StringExt.EMPTY);

    if (tmpFilePath != null) {
      command = command.replaceAll(map[_config.paramNameInp], tmpFilePath);
    }

    var isVerbose = Log.isDetailed;

    if (_options.isListOnly || isExpandContentOnly || !isVerbose) {
      Log.outInfo(command);
    }

    if (_options.isListOnly || isExpandContentOnly) {
      return true;
    }

    try {
      if (command.startsWith(Config.CMD_SUB + StringExt.SPACE)) {
        var oldCurDir = Directory.current;
        Doul.exec(command.splitCommandLine(skipCharCount: Config.CMD_SUB.length));
        Directory.current = oldCurDir;
      }
      else {
        var exitCodes = waitFor<List<ProcessResult>>(
            Shell(verbose: isVerbose, runInShell: false).run(command));

        if (exitCodes.any((x) => (x.exitCode != 0))) {
          throw Exception('Command failed${isVerbose ? StringExt.EMPTY : '\n\n${command}\n\n'}');
        }
      }
    }
    catch (e) {
      throw Exception(e.toString());
    }

    if (tmpFilePath != null) {
      var tmpFile = File(tmpFilePath);

      tmpFile.deleteIfExistsSync();
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  File expandInpContent(File inpFile, String outFilePath, String tmpFilePath, Map<String, String> map) {
    var text = StringExt.EMPTY;

    if (inpFile == null) {
      text = stdin.readAsStringSync();
    }
    else {
      text = (inpFile.readAsStringSync() ?? StringExt.EMPTY);
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

    if (Log.isUltimate) {
      Log.debug('\n...content of expanded "${inpFile.path}":\n');
      Log.debug(text);
    }

    if (isStdOut) {
      Log.out(text);
      return null;
    }
    else {
      var outDir = Directory(Path.dirname(outFilePath));

      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      if (Directory(outFilePath).existsSync()) {
        var inpFilePath = inpFile.path;
        var outFileName = (inpFilePath.startsWith(curDirName) ? inpFilePath.substring(curDirName.length) : Path.basename(inpFilePath));

        var rootPrefixLen = Path.rootPrefix(outFileName).length;

        if (rootPrefixLen > 0) {
          outFileName = outFileName.substring(rootPrefixLen);
        }

        outFilePath = Path.join(outFilePath, outFileName);
      }

      var tmpFile = File(tmpFilePath ?? outFilePath);

      tmpFile.deleteIfExistsSync();
      tmpFile.writeAsStringSync(text);

      if (inpFile.path == outFilePath) {
        tmpFile.renameSync(outFilePath);
      }

      return (isExpandContentOnly ? null : tmpFile);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandInpNames(String value, Map<String, String> map) {
    String inpParamName;
    var result = value;

    for (var i = 0, n = _inpParamNames.length; i < n; i++) {
      inpParamName = _inpParamNames[i];
      result = result.replaceAll(inpParamName, (map[inpParamName] ?? StringExt.EMPTY));
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, String> expandMap(Map<String, String> map, String curDirName, String inpFilePath) {
    var newMap = <String, String>{};
    newMap.addAll(map);

    var paramNameCurDir = _config.paramNameCurDir;
    var paramNameInp = _config.paramNameInp;

    newMap.forEach((k, v) {
      if (StringExt.isNullOrBlank(k)) {
        return;
      }
      if (k == paramNameCurDir) {
        newMap[k] = curDirName;
      }
      else if (k == paramNameInp) {
        newMap[k] = inpFilePath;
      }
      else {
        if (v.contains(paramNameCurDir)) {
          newMap[k] = v.replaceAll(paramNameCurDir, curDirName);
        }

        newMap[k] = getValue(newMap, key: k, canReplace: true);

        if (_config.isParamWithPath(k)) {
          newMap[k] = newMap[k].getFullPath();
        }
      }
    });

    return newMap;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getActualInpFilePath(String inpFilePath, String outFilePath) {
    if (isStdIn || (isExpandContentOnly && (inpFilePath != outFilePath)) || !canExpandContent) {
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
    else {
      return inpFilePath;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String getCurDirName(Map<String, String> map) {
    var curDirName = (getValue(map, key: _config.paramNameCurDir, canReplace: false) ?? StringExt.EMPTY);
    curDirName = curDirName.getFullPath();

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getDirList(String pattern) => DirectoryExt.pathListExSync(pattern);

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
        filePathTrim = Path.join(curDirName, filePathTrim).getFullPath();
      }

      lst = getDirList(filePathTrim);
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: ${filePath}');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getValue(Map<String, String> map, {String key, String value, Map<String, String> mapPrev, bool canReplace}) {
    if ((value == null) && (key != null) && map.containsKey(key)) {
      value = map[key];
    }

    if ((canReplace ?? false) && !StringExt.isNullOrBlank(value)) {
      for (String oldValue; (oldValue != value); ) {
        oldValue = value;

        map.forEach((k, v) {
          if ((k != key) && !StringExt.isNullOrBlank(k)) {
            if ((k == _config.paramNameInp) || (k == _config.paramNameOut)) {
              if (GlobExt.isGlobPattern(v)) {
                return;
              }
            }

            value = value.replaceAll(k, v);

            var hasPath = false;

            if (value.contains(_config.paramNameCurDir)) {
              value = value.replaceAll(_config.paramNameCurDir, curDirName);
            }
            else {
              hasPath = (detectPathsRE != null) && detectPathsRE.hasMatch(k) && (k != _config.paramNameDetectPaths);
            }

            if (hasPath) {
              value = value.adjustPath();
            }
          }
        });
      }

      if ((key != null) && value.contains(key) && (mapPrev != null) && mapPrev.containsKey(key)) {
        value = value.replaceAll(key, mapPrev[key]);
      }
    }

    return (value ?? StringExt.EMPTY);
  }

  //////////////////////////////////////////////////////////////////////////////

}