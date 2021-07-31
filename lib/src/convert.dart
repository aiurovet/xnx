import 'dart:cli';
import 'dart:convert';
import 'dart:io';

import 'package:xnx/src/config_result.dart';
import 'package:xnx/src/config_file_loader.dart';
import 'package:xnx/src/config.dart';
import 'package:xnx/src/xnx.dart';
import 'package:xnx/src/file_oper.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';
import 'package:xnx/src/pack_oper.dart';
import 'package:xnx/src/ext/directory.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/ext/stdin.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:path/path.dart' as path_api;
import 'package:process_run/shell.dart';

class Convert {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String FILE_TYPE_TMP = '.tmp';
  static final RegExp EXE_SUB_RE = RegExp(r'^(-.?|--.*)$');
  static final RegExp EXE_SUB_PRINT_RE = RegExp(r'^--print([\s]|$)');

  //////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////

  bool canExpandContent;
  RegExp detectPathsRE;
  bool isExpandContentOnly;
  bool isProcessed;
  bool isStdIn;
  bool isStdOut;
  String curDirName;
  String outDirName;
  String startCmd;

  Config _config;
  List<String> _inpParamNames;
  List<String> _exeParamNames;
  Logger _logger;
  Options _options;

  //////////////////////////////////////////////////////////////////////////////

  Convert(Logger logger) {
    _logger = logger;
  }

  //////////////////////////////////////////////////////////////////////////////

  void exec(List<String> args) {
    startCmd = FileExt.getStartCommand();
    isProcessed = false;

    _config = Config(_logger);
    _options = _config.options;

    _config.exec(args: args, execFlatMap: execMapWithArgs);
    PackOper.compression = _options.compression;

    if (_options.isCmd) {
      execBuiltin(_options.plainArgs);
    }

    return;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execBuiltin(List<String> args, {bool isSilent}) {
    var argCount = (args?.length ?? 0);

    final isPrint = _options.isCmdPrint;
    final isCompress = _options.isCmdCompress;
    final isDecompress = _options.isCmdDecompress;
    final isMove = _options.isCmdMove;

    if (argCount <= 0) {
      throw Exception('No argument specified for the built-in command');
    }

    isSilent ??= _logger.isSilent;

    var end = (args.length - 1);
    var arg1 = (end >= 0 ? args[0] : null);
    var arg2 = (end >= 1 ? args[1] : null);

    if (isPrint) {
      execPrint(_options.plainArgs, isSilent: isSilent);
    }
    else if (isCompress || isDecompress) {
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

  bool execFile(String cmdTemplate, String inpFilePath, String outFilePath, Map<String, String> map) {
    var command = expandInpNames(cmdTemplate.replaceAll(_config.paramNameOut, outFilePath), map);
    command = command.replaceAll(_config.paramNameCurDir, curDirName);

    if (isExpandContentOnly) {
      var cli = command.splitCommandLine();
      var args = cli[1];
      var argc = args.length;

      if (argc > 0) {
        outFilePath = args[argc - 1];

        if (argc > 1) {
          inpFilePath = args[0];
        }
      }
    }

    var hasInpFile = (!isStdIn && !StringExt.isNullOrBlank(inpFilePath) && command.adjustPath().contains(inpFilePath));

    if (isExpandContentOnly && !hasInpFile) {
      throw Exception('Input file is undefined for ${_config.cmdNameExpand} operation');
    }

    var inpFile = (hasInpFile ? File(inpFilePath) : null);

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception('Input file is not found: "$inpFilePath"');
    }

    var hasOutFile = (!isStdOut && !StringExt.isNullOrBlank(outFilePath) && !Directory(outFilePath).existsSync());

    String tmpFilePath;

    var isSamePath = (hasInpFile && hasOutFile && path_api.equals(inpFilePath, outFilePath));

    if (canExpandContent && (!isExpandContentOnly || isSamePath)) {
      tmpFilePath = getActualInpFilePath(inpFilePath, outFilePath);
    }

    _logger.debug('Temp file path: "${tmpFilePath ?? StringExt.EMPTY}"');

    var outFile = (hasOutFile ? File(outFilePath) : null);

    if (!_options.isForced && hasInpFile && hasOutFile && !isSamePath) {
      var isChanged = (outFile.compareLastModifiedStampToSync(toFile: inpFile) < 0);

      if (!isChanged) {
        isChanged = (outFile.compareLastModifiedStampToSync(toLastModifiedStamp: _config.lastModifiedStamp) < 0);
      }

      if (!isChanged) {
        _logger.information('Unchanged: "$outFilePath"');
        return false;
      }
    }

    if (hasInpFile && hasOutFile && !isSamePath) {
      outFile.deleteIfExistsSync();
    }

    if (canExpandContent && hasInpFile) {
      expandInpContent(inpFile, outFilePath, tmpFilePath, map);
    }

    command = (getValue(map, value: command, canReplace: true) ?? StringExt.EMPTY);

    var tmpFile = (tmpFilePath != null ? File(tmpFilePath) : null);

    if (tmpFile != null) {
      command = command.replaceAll(inpFilePath, tmpFilePath);
    }

    var isPrint = EXE_SUB_PRINT_RE.hasMatch(command);
    var canRun = (!_options.isListOnly && !isExpandContentOnly);

    if (!canRun || !isPrint) {
      _logger.out(command);
    }

    if (!canRun) {
      return true;
    }

    const isProcessRunSyncUsed = true;

    String errMsg;
    var isSuccess = false;
    var oldCurDir = Directory.current;
    var resultCount = 0;
    ProcessResult result;
    List<ProcessResult> results;

    try {
      if (StringExt.isNullOrBlank(command)) {
        // Shouldn't happen, but just in case
        return true;
      }

      var cli = command.splitCommandLine();
      var exe = cli[0][0];
      var args = cli[1];

      if (EXE_SUB_RE.hasMatch(exe)) {
        if (isPrint) {
          execPrint(args);
        }
        else {
          args.insert(0, exe);
          Xnx(logger: _logger).exec(args);
        }

        isSuccess = true;
      }
      else {
        if (isProcessRunSyncUsed) {
          result = Process.runSync(exe, args, workingDirectory: curDirName);
          isSuccess = (result.exitCode == 0);
        }
        else {
          results = waitFor<List<ProcessResult>>(
              Shell(
                  environment: Platform.environment,
                  verbose: _logger.isInfo,
                  commandVerbose: false,
                  commentVerbose: false,
                  runInShell: false
              ).run(command)
          );

          resultCount = results?.length ?? 0;
          result = (resultCount <= 0 ? null : results[0]);
          isSuccess = (resultCount <= 0 ? false : !results.any((x) => (x.exitCode != 0)));
        }
      }
    }
    on Error catch (e) {
      errMsg = e.toString();
    }
    on Exception catch (e) {
      errMsg = e.toString();
    }

    tmpFile?.deleteIfExistsSync();
    Directory.current = oldCurDir;

    if (result != null) {
      if (isProcessRunSyncUsed) {
        if (result.stdout?.isNotEmpty ?? false) {
          _logger.out(result.stdout);
        }
      }
      else {
        if (results.outLines?.isNotEmpty ?? false) {
          _logger.out(results.outLines.toString());
        }
      }

      if (!isSuccess) {
        if (isProcessRunSyncUsed) {
          _logger.error('Exit code: ${result.exitCode}');
          _logger.error('\n*** Error:\n\n${result.stderr ?? 'No error or warning message found'}');
        }
        else {
          var unitsEnding = (resultCount == 1 ? '' : 's');

          _logger.error('Exit code$unitsEnding: ${results.map((x) => x.exitCode).join(', ')}');
          _logger.error('\n*** Error$unitsEnding:\n\n${results.errLines}');
        }
      }
    }

    if (!isSuccess) {
      throw Exception(errMsg);
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execMap(List<String> plainArgs, Map<String, String> map) {
    var mapCurr = <String, String>{};

    map[ConfigFileLoader.ALL_ARGS] = (
      plainArgs?.isEmpty ?? true ?
      StringExt.EMPTY :
      plainArgs.map((x) => x?.quote() ?? StringExt.EMPTY).join(StringExt.SPACE)
    );

    curDirName = getCurDirName(map);

    var inpFilePath = (getValue(map, key: _config.paramNameInp, canReplace: true) ?? StringExt.EMPTY);
    var hasInpFile = !StringExt.isNullOrBlank(inpFilePath);

    if (hasInpFile) {
      if (!path_api.isAbsolute(inpFilePath)) {
        inpFilePath = path_api.join(curDirName, inpFilePath);
      }

      if (inpFilePath.contains(_config.paramNameInp) ||
          inpFilePath.contains(_config.paramNameInpDir) ||
          inpFilePath.contains(_config.paramNameInpExt) ||
          inpFilePath.contains(_config.paramNameInpName) ||
          inpFilePath.contains(_config.paramNameInpNameExt) ||
          inpFilePath.contains(_config.paramNameInpPath) ||
          inpFilePath.contains(_config.paramNameInpSubDir) ||
          inpFilePath.contains(_config.paramNameInpSubPath)) {
        inpFilePath = expandInpNames(inpFilePath, map);
      }

      inpFilePath = inpFilePath.getFullPath();
    }

    var subStart = (hasInpFile ? (inpFilePath.length - path_api.basename(inpFilePath).length) : 0);
    var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

    for (var inpFilePathEx in inpFilePaths) {
      inpFilePathEx = inpFilePathEx.adjustPath();

      mapCurr = expandMap(map, curDirName, inpFilePathEx);

      var detectPathsPattern = getValue(mapCurr, key: _config.paramNameDetectPaths, canReplace: true);

      if (StringExt.isNullOrBlank(detectPathsPattern)) {
        detectPathsRE = null;
      }
      else {
        detectPathsRE = RegExp(detectPathsPattern, caseSensitive: false);
      }

      var command = getValue(mapCurr, key: _config.paramNameRun, canReplace: false);

      if (StringExt.isNullOrBlank(command)) {
        command = getValue(mapCurr, key: _config.paramNameCmd, canReplace: false);
      }

      isExpandContentOnly = command.startsWith(_config.cmdNameExpand);
      canExpandContent = (isExpandContentOnly || StringExt.parseBool(getValue(mapCurr, key: _config.paramNameCanExpandContent, canReplace: false)));

      if (!StringExt.isNullOrBlank(curDirName)) {
        _logger.debug('Setting current directory to: "$curDirName"');
        Directory.current = curDirName;
      }

      if (StringExt.isNullOrBlank(command)) {
        if (_config.options.isListOnly) {
          _logger.out(jsonEncode(mapCurr) + (_config.options.isAppendSep ? ConfigFileLoader.RECORD_SEP : StringExt.EMPTY));
        }
        return true;
      }

      var outFilePath = (getValue(mapCurr, key: _config.paramNameOut, canReplace: true) ?? StringExt.EMPTY).adjustPath();
      var hasOutFile = outFilePath.isNotEmpty;

      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);

      var outFilePathEx = (hasOutFile ? outFilePath : inpFilePathEx);

      if (hasInpFile) {
        var dirName = path_api.dirname(inpFilePathEx);
        var inpNameExt = path_api.basename(inpFilePathEx);

        mapCurr[_config.paramNameInpDir] = dirName;
        mapCurr[_config.paramNameInpSubDir] = (dirName.length <= subStart ? StringExt.EMPTY : dirName.substring(subStart));
        mapCurr[_config.paramNameInpNameExt] = inpNameExt;
        mapCurr[_config.paramNameInpExt] = path_api.extension(inpNameExt);
        mapCurr[_config.paramNameInpName] = path_api.basenameWithoutExtension(inpNameExt);
        mapCurr[_config.paramNameInpPath] = inpFilePathEx;
        mapCurr[_config.paramNameInpSubPath] = inpFilePathEx.substring(subStart);
        mapCurr[_config.paramNameThis] = startCmd;

        mapCurr.forEach((k, v) {
          if ((v != null) && !_exeParamNames.contains(k) && !_inpParamNames.contains(k)) {
            mapCurr[k] = expandInpNames(v, mapCurr);
          }
        });

        if (hasOutFile) {
          outFilePathEx = expandInpNames(outFilePathEx, mapCurr);
          outFilePathEx = path_api.join(curDirName, outFilePathEx).getFullPath();
        }

        outFilePathEx = outFilePathEx.adjustPath();

        _logger.debug('''

Input dir:       "${mapCurr[_config.paramNameInpDir]}"
Input sub-dir:   "${mapCurr[_config.paramNameInpSubDir]}"
Input name:      "${mapCurr[_config.paramNameInpName]}"
Input extension: "${mapCurr[_config.paramNameInpExt]}"
Input name-ext:  "${mapCurr[_config.paramNameInpNameExt]}"
Input path:      "${mapCurr[_config.paramNameInpPath]}"
Input sub-path:  "${mapCurr[_config.paramNameInpSubPath]}"
        ''');
      }

      outDirName = (isStdOut ? StringExt.EMPTY : path_api.dirname(outFilePathEx));

      _logger.debug('''

Output dir:  "$outDirName"
Output path: "${outFilePathEx ?? StringExt.EMPTY}"
        ''');

      // if (isStdOut && !isExpandContentOnly) {
      //   throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISPLAY}. Use pipe and a separate configuration file per each output.');
      // }

      var isOK = execFile(command.replaceAll(inpFilePath, inpFilePathEx), inpFilePathEx, outFilePathEx, mapCurr);

      if (isOK) {
        isProcessed = true;
      }
      else {
        break;
      }
    }

    return isProcessed;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execMapWithArgs(Map<String, String> map) {
    var plainArgs = _options.plainArgs;

    _exeParamNames = _config.getExeParamNames();
    _inpParamNames = _config.getInpParamNames();

    if ((plainArgs?.length ?? 0) <= 0) {
      plainArgs = [ null ];
    }

    if (_options.isEach) {
      for (var i = 0, n = plainArgs.length; i < n; i++) {
        var plainArg = plainArgs[i];

        if (execMap([plainArg], map)) {
          isProcessed = true;
        }
      }
    }
    else {
      if (execMap(plainArgs, map)) {
        isProcessed = true;
      }
    }

    if ((isStdOut != null) && !isStdOut && !isProcessed) {
      var key = _config.paramNameRun;
      var cmd = map[key];

      if (StringExt.isNullOrBlank(cmd)) {
        key = _config.paramNameCmd;
        cmd = map[key];
      }

      cmd = getValue(map, key: key, value: cmd, canReplace: true);

      _logger.out('Output is up to date for\n\t$cmd\n');
    }

    return ConfigResult.ok;
  }

  //////////////////////////////////////////////////////////////////////////////

  void execPrint(List<String> args, {bool isSilent}) {
    if (!(isSilent ?? false)) {
      _logger.out(args?.join(StringExt.SPACE) ?? StringExt.EMPTY);
    }
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

    if (_logger.isDebug) {
      _logger.debug('\n...content of expanded "${inpFile.path}":\n');
      _logger.debug(text);
    }

    if (isStdOut) {
      _logger.out(text);
      return null;
    }
    else {
      var inpFilePath = inpFile.path;

      var inpDirName = path_api.dirname(inpFilePath);
      var inpFileName = path_api.basename(inpFilePath);

      var outDirName = path_api.dirname(outFilePath);
      var outFileName = path_api.basename(outFilePath);

      if (path_api.equals(inpFileName, outFileName)) {
        outFileName = inpFileName;
      }

      if (path_api.equals(inpDirName, outDirName)) {
        outDirName = inpDirName;
      }

      outFilePath = path_api.join(outDirName, outFileName);

      var outDir = Directory(outDirName);

      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      if (Directory(outFilePath).existsSync()) {
        outFileName = (inpFilePath.startsWith(curDirName) ? inpFilePath.substring(curDirName.length) : path_api.basename(inpFilePath));

        var rootPrefixLen = path_api.rootPrefix(outFileName).length;

        if (rootPrefixLen > 0) {
          outFileName = outFileName.substring(rootPrefixLen);
        }

        outFilePath = path_api.join(outFilePath, outFileName);
      }

      var tmpFile = File(tmpFilePath ?? outFilePath);

      tmpFile.deleteIfExistsSync();
      tmpFile.writeAsStringSync(text);

      if (path_api.equals(inpFilePath, outFilePath)) {
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
      }
    });

    return newMap;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getActualInpFilePath(String inpFilePath, String outFilePath) {
    if (isStdIn || (isExpandContentOnly && !path_api.equals(inpFilePath, outFilePath)) || !canExpandContent) {
      return inpFilePath;
    }
    else if (!isStdOut) {
      if (StringExt.isNullOrBlank(outFilePath)) {
        return StringExt.EMPTY;
      }
      else {
        var tmpFileName = (path_api.basenameWithoutExtension(outFilePath) +
            FILE_TYPE_TMP + path_api.extension(inpFilePath));
        var tmpDirName = path_api.dirname(outFilePath);

        return path_api.join(tmpDirName, tmpFileName);
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

    var filePathTrim = filePath?.trim() ?? StringExt.EMPTY;

    var lst = <String>[];

    if (filePath == StringExt.STDIN_PATH) {
      lst.add(filePath);
    }
    else {
      if (!path_api.isAbsolute(filePathTrim)) {
        filePathTrim = path_api.join(curDirName, filePathTrim).getFullPath();
      }

      lst = getDirList(filePathTrim);
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: $filePath');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getValue(Map<String, String> map, {String key, String value, bool canReplace}) {
    if ((value == null) && (key != null) && map.containsKey(key)) {
      value = map[key];

      if (key == _config.paramNameCurDir) {
        value = value.getFullPath();
        map[key] = value;
      }
    }

    if ((canReplace ?? false) && !StringExt.isNullOrBlank(value)) {
      for (String oldValue; (oldValue != value); ) {
        oldValue = value;

        map.forEach((k, v) {
          if ((k != key) && !StringExt.isNullOrBlank(k)) {
            value = value.replaceAll(k, v);
          }
        });
      }

      if ((key != null) && value.contains(key) && (map != null) && map.containsKey(key)) {
        value = value.replaceAll(key, map[key]);
      }
    }

    if (value?.contains(_config.paramNameCurDir) ?? false) {
      value = value.replaceAll(_config.paramNameCurDir, curDirName);
    }

    return (value ?? StringExt.EMPTY);
  }

  //////////////////////////////////////////////////////////////////////////////

}