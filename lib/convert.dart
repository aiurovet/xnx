import 'dart:cli';
import 'dart:io';

import 'package:doul/app_file_loader.dart';
import 'package:doul/ext/glob.dart';
import 'package:path/path.dart' as Path;
import 'package:process_run/shell_run.dart';

import 'arch_oper.dart';
import 'config.dart';
import 'file_oper.dart';
import 'log.dart';
import 'options.dart';
import 'ext/directory.dart';
import 'ext/file.dart';
import 'ext/file_system_entity.dart';
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

  bool canReplaceContent;
  bool isReplaceContentOnly;
  bool isStdIn;
  bool isStdOut;
  String outDirName;

  Config _config;
  List<String> _inpParamNames;
  Options _options;

  //////////////////////////////////////////////////////////////////////////////

  void exec(List<String> args) {
    _config = Config();
    var maps = _config.exec(args);
    _options = _config.options;
    var plainArgs = _options.plainArgs;

    if ((maps == null) && _options.isCmd) {
      execBuiltin(_options.plainArgs);
      return;
    }

    _inpParamNames = _config.getInpParamNames();

    var isProcessed = false;

    if ((plainArgs?.length ?? 0) <= 0) {
      plainArgs = [ null ];
    }

    for (var i = 0, n = plainArgs.length; i < n; i++) {
      var mapPrev = <String, String>{};
      var plainArg = plainArgs[i];

      for (var mapOrig in maps) {
        if (execMap(plainArg, mapOrig, mapPrev)) {
          isProcessed = true;
        }
      }
    }

    if ((isStdOut != null) && !isStdOut && !isProcessed) {
      Log.outInfo('All output files are up to date.');
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

    if (_options.isCmdCompress || _options.isCmdDecompress) {
      final archMode = (_options.isCmdTar || _options.isCmdUntar ? ArchMode.Tar :
                        _options.isCmdZip || _options.isCmdUnzip ? ArchMode.Zip : null);

      if (_options.isCmdTar || _options.isCmdZip) {
        ArchOper.archSync(fromPaths: args, end: end, archMode: archMode, isMove: _options.isCmdMove, isSilent: isSilent);
      }
      else if ((_options.isCmdUntar) || _options.isCmdUnzip) {
        if (argCount != 2) {
          throw Exception('Invalid arguments: ${args}. Expected: from-path and to-dir');
        }
        ArchOper.unarchSync(args[0], args[1], archMode: archMode, isMove: _options.isCmdMove, isSilent: isSilent);
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
    var isProcessed = false;
    var isKeyArgsFound = false;
    var mapCurr = <String, String>{};
    var keyArgs = AppFileLoader.ALL_ARGS;

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

    var curDirName = getCurDirName(mapOrig);

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
        inpFilePath = replaceInpNames(inpFilePath, mapPrev);
      }

      inpFilePath = inpFilePath.getFullPath();
    }

    var subStart = (hasInpFile ? (inpFilePath.length - Path.basename(inpFilePath).length) : 0);
    var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

    for (var inpFilePathEx in inpFilePaths) {
      mapCurr.addAll(expandMap(mapOrig, curDirName, inpFilePathEx));

      mapPrev.forEach((k, v) {
        if (!mapCurr.containsKey(k)) {
          mapCurr[k] = v;
        }
      });

      var command = getValue(mapCurr, key: _config.paramNameCmd, canReplace: false);
      isReplaceContentOnly = (command == Config.CMD_REPLACE);
      canReplaceContent = (isReplaceContentOnly || StringExt.parseBool(getValue(mapCurr, key: _config.paramNameCanReplaceContent, canReplace: false)));

      if (!StringExt.isNullOrBlank(curDirName)) {
        Log.debug('Setting current directory to: "${curDirName}"');
        Directory.current = curDirName;
      }

      if (StringExt.isNullOrBlank(command)) {
        throw Exception('Undefined command for\n\n${mapCurr.toString()}');
      }

      var outFilePath = (getValue(mapCurr, key: _config.paramNameOut, mapPrev: mapPrev, canReplace: true) ?? StringExt.EMPTY);
      var hasOutFile = !StringExt.isNullOrBlank(outFilePath);

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

        mapCurr.forEach((k, v) {
          if ((v != null) && (k != _config.paramNameCmd) && !_inpParamNames.contains(k)) {
            mapCurr[k] = replaceInpNames(v, mapCurr);
          }
        });

        if (hasOutFile) {
          outFilePathEx = replaceInpNames(outFilePathEx, mapCurr);
          outFilePathEx = Path.join(curDirName, outFilePathEx).getFullPath();
        }

        //command = replaceInpNames(command, mapCurr);
      }

      outDirName = (isStdOut ? StringExt.EMPTY : Path.dirname(outFilePathEx));

      if (isStdOut && !isReplaceContentOnly) {
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
    var hasInpFile = (!isStdIn && !StringExt.isNullOrBlank(inpFilePath));

    if (isReplaceContentOnly && !hasInpFile) {
      throw Exception('Input file is undefined for ${Config.CMD_REPLACE} operation');
    }

    var inpFile = (hasInpFile ? File(inpFilePath) : null);

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception('Input file is not found: "${inpFilePath}"');
    }

    var hasOutFile = (!isStdOut && !StringExt.isNullOrBlank(outFilePath));

    String tmpFilePath;

    if (canReplaceContent && (!isReplaceContentOnly || (hasInpFile && hasOutFile && (inpFilePath == outFilePath)))) {
      tmpFilePath = getActualInpFilePath(inpFilePath, outFilePath);
    }

    var cmdTemplateEx = cmdTemplate;

    if (isReplaceContentOnly) {
      cmdTemplateEx += ' "${_config.paramNameInp}" "${_config.paramNameOut}"';
    }

    var command = cmdTemplateEx
      .replaceAll(_config.paramNameOut, outFilePath)
      .replaceAll(_config.paramNameInp, (tmpFilePath ?? inpFilePath));

    var outFile = (hasOutFile ? File(outFilePath) : null);

    if (!_options.isForced && (inpFilePath != outFilePath)) {
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

    if (canReplaceContent) {
      replaceInpContent(inpFile, outFilePath, tmpFilePath, map);
    }

    command = (getValue(map, value: command, canReplace: true) ?? StringExt.EMPTY);

    var isVerbose = Log.isDetailed;

    if (_options.isListOnly || isReplaceContentOnly || !isVerbose) {
      Log.outInfo(command);
    }

    if (_options.isListOnly || isReplaceContentOnly) {
      return true;
    }

    try {
      var exitCodes = waitFor<List<ProcessResult>>(
          Shell(verbose: isVerbose, runInShell: false).run(command));

      if (exitCodes.any((x) => (x.exitCode != 0))) {
        throw Exception('Command failed${isVerbose ? StringExt.EMPTY : '\n\n${command}\n\n'}');
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

  File replaceInpContent(File inpFile, String outFilePath, String tmpFilePath, Map<String, String> map) {
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
      var outDir = Directory(outDirName);

      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      var tmpFile = File(tmpFilePath ?? outFilePath);

      tmpFile.deleteIfExistsSync();
      tmpFile.writeAsStringSync(text);

      if (inpFile.path == outFilePath) {
        tmpFile.renameSync(outFilePath);
      }

      return (isReplaceContentOnly ? null : tmpFile);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String replaceInpNames(String value, Map<String, String> map) {
    String inpParamName;
    var result = value;

    for (var i = 0, n = _inpParamNames.length; i < n; i++) {
      inpParamName = _inpParamNames[i];
      result = result.replaceAll(inpParamName, map[inpParamName]);
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
    if (isStdIn || (isReplaceContentOnly && (inpFilePath != outFilePath)) || !canReplaceContent) {
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
    var curDirName = (getValue(map, key: _config.paramNameCurDir, canReplace: false) ?? StringExt.EMPTY);
    curDirName = curDirName.getFullPath();

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> getDirList(String pattern) {
    var dir = Directory(pattern);

    List<String> lst;

    if (dir.existsSync()) {
      lst = dir.pathListSync(null, checkExists: false);
    }
    else {
      dir = Directory(GlobExt.getDirectoryName(pattern));
      lst = dir.pathListSync(pattern, checkExists: false);
    }

    return lst;
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

    if (!StringExt.isNullOrBlank(value)) {
      if ((canReplace ?? false) && (value != null)) {
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

      if ((key != null) && value.contains(key) && (mapPrev != null) && mapPrev.containsKey(key)) {
        value = value.replaceAll(key, mapPrev[key]);
      }
    }

    return (value ?? StringExt.EMPTY);
  }

  //////////////////////////////////////////////////////////////////////////////

}