import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:thin_logger/thin_logger.dart';
import 'package:xnx/command.dart';

import 'package:xnx/config_result.dart';
import 'package:xnx/config_file_loader.dart';
import 'package:xnx/config.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/flat_map.dart';
import 'package:xnx/file_oper.dart';
import 'package:xnx/escape_mode.dart';
import 'package:xnx/options.dart';
import 'package:xnx/pack_oper.dart';
import 'package:xnx/ext/directory.dart';
import 'package:xnx/ext/file.dart';
import 'package:xnx/ext/file_system_entity.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/stdin.dart';
import 'package:xnx/ext/string.dart';
import 'package:xnx/regexp_ex.dart';

class Convert {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String fileTypeTmp = '.tmp';

  static final RegExp rexIsKeyEnvVarName = RegExp(r'^\$');
  static final RegExp rexIsSubCmd = RegExp(r'^[\s]*[\-]');
  static final RegExp rexIsSubCmdExpand = RegExp(r'^(^|[\s])(-E|--expand)([\s]|$)');
  static final RegExp rexIsSubCmdKeepTime = RegExp(r'(^|[\s])(--(copy|copy-newer|move|move-newer))([\s]|$)');

  //////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////

  bool canExpandContent = false;
  RegExp? rexDetectPaths;
  bool isExpandContentOnly = false;
  bool isMinExpand = false;
  bool isProcessed = false;
  bool isStdIn = false;
  bool isStdOut = false;
  bool isSubRun = false;
  String curDirName = '';
  String outDirName = '';
  String startCmd = '';

  Config _config = Config();
  Logger _logger = Logger();
  Options options = Options();

  List<String> _exeParamNames = [];
  List<String> _inpParamNames = [];

  //////////////////////////////////////////////////////////////////////////////

  Convert(Logger logger) {
    _logger = logger;
  }

  //////////////////////////////////////////////////////////////////////////////

  void exec(List<String> args) {
    startCmd = Command.getStartCommandText();
    isProcessed = false;

    _config = Config(_logger);
    options = _config.options;

    options.parseArgs(args);
    PackOper.compression = options.compression;

    if (options.isCmd) {
      execBuiltin(options.plainArgs);
    }
    else {
      _config.exec(args: args, execFlatMap: execMapWithArgs);
    }

    return;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execBuiltin(List<String>? args, {bool isSilent = false}) {
    final isPrint = options.isCmdPrint;
    final isPrintCwd = options.isCmdPrintCwd;
    final isPrintEnv = options.isCmdPrintEnv;
    final isCompress = options.isCmdCompress;
    final isDecompress = options.isCmdDecompress;
    final isListOnly = options.isListOnly;
    final isMove = options.isCmdMove;

    if (isPrintEnv) {
      Platform.environment.forEach((key, value) {
        _logger.out('$key=$value');
      });
      return true;
    }
    else if (isPrintCwd) {
      _logger.out(Path.currentDirectoryName);
      return true;
    }

    if ((args == null) || args.isEmpty) {
      throw Exception('No argument specified for the built-in command');
    }

    var argCount = (args.length - 1);
    var arg1 = (argCount >= 0 ? args[0] : null);
    var arg2 = (argCount >= 1 ? args[1] : null);

    if (isPrint) {
      Command.print(_logger, options.plainArgs, isSilent: isSilent);
    }
    else if (isCompress || isDecompress) {
      final archPath = (isDecompress ? arg1 : args[argCount < 0 ? 0 : argCount]);
      final archType = PackOper.getPackType(options.archType, archPath);

      if (archType != null) {
        final isTar = PackOper.isPackTypeTar(archType);

        if (isTar || (archType == PackType.zip)) {
          if (isCompress) {
            PackOper.archiveSync(archType, args, isListOnly: isListOnly, isMove: isMove, isSilent: isSilent);
          }
          else if (arg1 != null) {
            PackOper.unarchiveSync(archType, arg1, arg2, isListOnly: isListOnly, isMove: isMove, isSilent: isSilent);
          }
        }
        else if (arg1 != null) {
          if (isCompress) {
            PackOper.compressSync(archType, arg1, toPath: arg2, isListOnly: isListOnly, isMove: true, isSilent: isSilent);
          }
          else {
            PackOper.uncompressSync(archType, arg1, toPath: arg2, isListOnly: isListOnly, isMove: true, isSilent: isSilent);
          }
        }
      }
      else if (archPath == null) {
        throw Exception('Undefined archive file');
      }
      else {
        throw Exception('Undefined type of archiving');
      }
    }
    else {
      if (options.isCmdCopy || options.isCmdCopyNewer) {
        FileOper.xferSync(args, isListOnly: isListOnly, isMove: false, isNewerOnly: options.isCmdCopyNewer, isSilent: isSilent);
      }
      else if (options.isCmdMove || options.isCmdMoveNewer) {
        FileOper.xferSync(args, isListOnly: isListOnly, isMove: true, isNewerOnly: options.isCmdMoveNewer, isSilent: isSilent);
      }
      else if (options.isCmdCreateDir) {
        FileOper.createDirSync(args, isListOnly: isListOnly, isSilent: isSilent);
      }
      else if (options.isCmdDelete) {
        FileOper.deleteSync(args, isListOnly: isListOnly, isSilent: isSilent, isRequired: false);
      }
      else if (options.isCmdFind) {
        FileOper.findSync(args, isSilent: isSilent);
      }
      else {
        return false;
      }
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execFile(String cmdTemplate, String inpFilePath, String outFilePath, FlatMap map) {
    var command = expandInpNames(cmdTemplate.replaceAll(_config.keywords.forOut, outFilePath), map);
    command = command.replaceAll(_config.keywords.forCurDir, curDirName);

    var isForced = options.isForced;
    var escapeMode = _config.escapeMode;

    if (isExpandContentOnly) {
      var cli = Command(source: command);
      var args = cli.args;

      if (cli.isInternal && args.isNotEmpty) {
        final parser = ArgParser();

        Options.addFlag(parser, Options.expand, (value) {
          // Dummy
        });
        Options.addFlag(parser, Options.forceConvert, (value) {
          if (value) {
            isForced = value;
          }
        });

        Options.addOption(parser, Options.escape, (value) {
          if ((value != null) && value.isNotEmpty) {
            escapeMode = Options.parseEscapeMode(value);
          }
        });

        var result = parser.parse(args);
        var paths = result.rest;

        var pathCount = paths.length;

        if (pathCount > 0) {
          inpFilePath = paths[0];

          if (pathCount > 1) {
            outFilePath = paths[1];
          }
          else {
            outFilePath = inpFilePath;
            isForced = true;
          }
        }
      }
    }

    var hasInpFile = (!isStdIn && !inpFilePath.isBlank() && Path.contains(command, inpFilePath));

    if (isExpandContentOnly && !hasInpFile) {
      throw Exception('Input file path "$inpFilePath" is empty or not found in ${Path.adjust(command)}');
    }

    var inpFile = (hasInpFile ? Path.fileSystem.file(inpFilePath) : null);

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception(Path.appendCurDirIfPathIsRelative('Input file is not found: ', inpFilePath));
    }

    var hasOutFile = (!isStdOut && !outFilePath.isBlank() && !Path.fileSystem.directory(outFilePath).existsSync());

    var tmpFilePath = '';

    var isSamePath = (hasInpFile && hasOutFile && Path.equals(inpFilePath, outFilePath));

    if (canExpandContent && (!isExpandContentOnly || isSamePath)) {
      tmpFilePath = getActualInpFilePath(inpFilePath, outFilePath);
    }

    if (_logger.isVerbose) {
      _logger.verbose('Temp file path: "$tmpFilePath"');
    }

    var outFile = (hasOutFile ? Path.fileSystem.file(outFilePath) : null);

    if (!isForced && (inpFile != null) && (outFile != null) && !isSamePath) {
      var isChanged = (outFile.compareLastModifiedStampToSync(toFile: inpFile) < 0);

      if (!isChanged && !rexIsSubCmdKeepTime.hasMatch(command)) {
        isChanged = (outFile.compareLastModifiedStampToSync(toLastModifiedStamp: _config.lastModifiedStamp) < 0);
      }

      if (!isChanged) {
        _logger.info('Up to date: "$outFilePath"');
        return false;
      }
    }

    if ((inpFile != null) && (outFile != null) && !isSamePath) {
      outFile.deleteIfExistsSync();
    }

    if (canExpandContent && (inpFile != null)) {
      expandInpContent(inpFile, outFilePath, tmpFilePath, escapeMode, map);
    }

    command = getValue(map, value: command, canReplace: true);

    var tmpFile = (tmpFilePath.isBlank() ? null : Path.fileSystem.file(tmpFilePath));

    if (tmpFile != null) {
      command = Path.replaceAll(command, inpFilePath, tmpFilePath);
    }

    Command(source: command, logger: _logger)
      .exec(canExec: !options.isListOnly && !isExpandContentOnly, canShow: true);

    tmpFile?.deleteIfExistsSync();

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execMap(List<String> plainArgs, FlatMap map) {
    var mapCurr = FlatMap();

    map[ConfigFileLoader.allArgs] = (plainArgs.isEmpty ? '' : plainArgs.map((x) => x.quote()).join(' '));
    curDirName = getCurDirName(map, true);

    var inpFilePath = getValue(map, key: _config.keywords.forInp, canReplace: true);
    var hasInpFile = !inpFilePath.isBlank();

    if (hasInpFile) {
      if (!Path.isAbsolute(inpFilePath)) {
        inpFilePath = Path.join(curDirName, inpFilePath);
      }

      if (inpFilePath.contains(_config.keywords.forInp) ||
          inpFilePath.contains(_config.keywords.forInpDir) ||
          inpFilePath.contains(_config.keywords.forInpExt) ||
          inpFilePath.contains(_config.keywords.forInpName) ||
          inpFilePath.contains(_config.keywords.forInpNameExt) ||
          inpFilePath.contains(_config.keywords.forInpPath) ||
          inpFilePath.contains(_config.keywords.forInpSubDir) ||
          inpFilePath.contains(_config.keywords.forInpSubPath)) {
        inpFilePath = expandInpNames(inpFilePath, map);
      }

      inpFilePath = Path.getFullPath(inpFilePath);
    }

    var subStart = (hasInpFile ? (inpFilePath.length - Path.basename(inpFilePath).length) : 0);
    var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

    for (var inpFilePathCurr in inpFilePaths) {
      var inpFilePathEx = Path.adjust(inpFilePathCurr);

      mapCurr = expandMap(map, curDirName, inpFilePathEx);

      if (!_config.take.isEmpty && _config.take.finalize(
          maskPattern: getValue(mapCurr, value: _config.take.maskPattern, canReplace: true),
          regexPattern: getValue(mapCurr, value: _config.take.regexPattern, canReplace: true),
        )) {
        if (!_config.take.hasMatch(inpFilePathEx)) {
          if (_logger.isVerbose) {
            _logger.verbose('Does not match the take pattern: "$inpFilePathCurr"');
          }
          continue;
        }
      }

      if (!_config.skip.isEmpty && _config.skip.finalize(
          maskPattern: getValue(mapCurr, value: _config.skip.maskPattern, canReplace: true),
          regexPattern: getValue(mapCurr, value: _config.skip.regexPattern, canReplace: true),
        )) {
        if (_config.skip.hasMatch(inpFilePathEx)) {
          if (_logger.isVerbose) {
            _logger.verbose('Skipping: "$inpFilePathCurr" (matches ${_config.skip.regexPattern ?? _config.skip.maskPattern})');
          }
          continue;
        }
      }

      var detectPathsPattern = getValue(mapCurr, key: _config.keywords.forDetectPaths, canReplace: true);

      if (detectPathsPattern.isBlank()) {
        rexDetectPaths = null;
      }
      else {
        rexDetectPaths = RegExp(detectPathsPattern, caseSensitive: false);
      }

      var command = getValue(mapCurr, key: _config.keywords.forRun, canReplace: false);

      if (command.isBlank()) {
        command = getValue(mapCurr, key: _config.keywords.forCmd, canReplace: false);
      }

      isSubRun = rexIsSubCmd.hasMatch(command);
      isExpandContentOnly = isSubRun && rexIsSubCmdExpand.hasMatch(command);
      canExpandContent = !options.isListOnly && (isExpandContentOnly || getValue(mapCurr, key: _config.keywords.forCanExpandContent, canReplace: false).parseBool());
      isMinExpand = getValue(mapCurr, key: _config.keywords.forMinExpand, canReplace: false).parseBool();

      if (!curDirName.isBlank()) {
        if (_logger.isVerbose) {
          _logger.verbose('Setting current directory to: "$curDirName"');
        }

        Path.currentDirectoryName = curDirName;
      }

      if (command.isBlank()) {
        if (_config.options.isListOnly) {
          _logger.out(jsonEncode(mapCurr) + (_config.options.isAppendSep ? ConfigFileLoader.recordSep : ''));
        }
        return true;
      }

      var outFilePath = Path.adjust(getValue(mapCurr, key: _config.keywords.forOut, canReplace: true));
      var hasOutFile = outFilePath.isNotEmpty;

      isStdIn = (inpFilePath == StringExt.stdinPath);
      isStdOut = (outFilePath == StringExt.stdoutPath);

      var outFilePathEx = (hasOutFile ? outFilePath : inpFilePathEx);

      if (hasInpFile) {
        var dirName = Path.dirname(inpFilePathEx);
        var inpNameExt = Path.basename(inpFilePathEx);

        mapCurr[_config.keywords.forInpDir] = dirName;
        mapCurr[_config.keywords.forInpSubDir] = (dirName.length <= subStart ? '' : dirName.substring(subStart));
        mapCurr[_config.keywords.forInpNameExt] = inpNameExt;
        mapCurr[_config.keywords.forInpExt] = Path.extension(inpNameExt);
        mapCurr[_config.keywords.forInpName] = Path.basenameWithoutExtension(inpNameExt);
        mapCurr[_config.keywords.forInpPath] = inpFilePathEx;
        mapCurr[_config.keywords.forInpSubPath] = inpFilePathEx.substring(subStart);
        mapCurr[_config.keywords.forThis] = startCmd;

        mapCurr.forEach((k, v) {
          if (!_exeParamNames.contains(k) && !_inpParamNames.contains(k)) {
            mapCurr[k] = expandInpNames(v, mapCurr);
          }
        });

        if (hasOutFile) {
          outFilePathEx = expandInpNames(outFilePathEx, mapCurr);
          outFilePathEx = Path.getFullPath(Path.join(curDirName, outFilePathEx));
        }

        outFilePathEx = Path.adjust(outFilePathEx);

        if (_logger.isVerbose) {
          _logger.verbose('''

Input dir:       "${mapCurr[_config.keywords.forInpDir]}"
Input sub-dir:   "${mapCurr[_config.keywords.forInpSubDir]}"
Input name:      "${mapCurr[_config.keywords.forInpName]}"
Input extension: "${mapCurr[_config.keywords.forInpExt]}"
Input name-ext:  "${mapCurr[_config.keywords.forInpNameExt]}"
Input path:      "${mapCurr[_config.keywords.forInpPath]}"
Input sub-path:  "${mapCurr[_config.keywords.forInpSubPath]}"
        ''');
        }
      }

      outDirName = (isStdOut ? '' : Path.dirname(outFilePathEx));

      if (_logger.isVerbose) {
        _logger.verbose('''

Output dir:  "$outDirName"
Output path: "$outFilePathEx"
        ''');
      }

      if (isStdOut && !isExpandContentOnly) {
        throw Exception('Command execution is not supported for the output to ${StringExt.stdoutDisplay}. Use pipe and a separate configuration file per each output.');
      }

      var isOK = execFile(command.replaceAll(inpFilePath, inpFilePathEx), inpFilePathEx, outFilePathEx, mapCurr);

      if (isOK) {
        isProcessed = true;
      }
      else {
        // File is up to date (in case of an error, execFile() throws an exception)
      }
    }

    return isProcessed;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execMapWithArgs(FlatMap map) {
    var plainArgs = options.plainArgs;

    _exeParamNames = _config.keywords.allForExe;
    _inpParamNames = _config.keywords.allForInp;

    if (plainArgs.isEmpty) {
      plainArgs = [ '' ];
    }

    if (options.isEach) {
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

    return ConfigResult.ok;
  }

  //////////////////////////////////////////////////////////////////////////////

  File? expandInpContent(File? inpFile, String outFilePath, String tmpFilePath, EscapeMode escapeMode, FlatMap map) {
    var tmpFile = (tmpFilePath.isBlank() ? null : Path.fileSystem.file(tmpFilePath));

    var inpPath = (inpFile?.path ?? StringExt.stdinDisplay);
    var outPath = (Path.equals(inpPath, outFilePath) ? '' : ' => "${tmpFile?.path ?? outFilePath}"');

    _logger.out('Expanding: "$inpPath"$outPath${isExpandContentOnly ? '' : '\n'}');

    // Get permissions and load the input as a text string

    var permissions = inpFile?.statSync();
    var text = (inpFile == null ? stdin.readAsStringSync() : inpFile.readAsStringSync());

    // Remove keywords and escape special characters

    var allKeywords = _config.keywords.all;
    var effectiveMap = <String, String>{};

    map.forEach((k, v) {
      if (allKeywords.contains(k)) {
        return;
      }

      if (isMinExpand && rexIsKeyEnvVarName.hasMatch(k)) {
        return;
      }

      switch (escapeMode) {
        case EscapeMode.html:
        case EscapeMode.xml:
          var vv = v
            .replaceAll('&', '&amp;')
            .replaceAll(StringExt.apos, '&apos;')
            .replaceAll('>', '&gt;')
            .replaceAll('<', '&lt;')
            .replaceAll(StringExt.quot, '&quot;');

          if (escapeMode == EscapeMode.html) {
            vv = vv
              .replaceAll('\x09', '&#9;');
          }

          effectiveMap[k] = vv;
          return;
        case EscapeMode.quotes:
          var vv = v
            .replaceAll(r'\', r'\\')
            .replaceAll(StringExt.quot, Env.escapeQuot)
            .replaceAll(StringExt.apos, Env.escapeApos);

          effectiveMap[k] = vv;
          return;
        default:
          effectiveMap[k] = v;
          return;
      }
    });

    // Expand data

    if (_logger.isVerbose) {
      _logger.verbose('...expanding patterns in the content');
    }

    var regExpPrefix = _config.keywords.regExpPrefix;
    var regExpSuffix = _config.keywords.regExpSuffix;

    for (var isDone = false; !isDone;) {
      effectiveMap.forEach((k, v) {
        isDone = true;

        var newText = '';

        var rx = RegExpEx.fromDecoratedPattern(k, prefix: regExpPrefix, suffix: regExpSuffix);

        if (_logger.isVerbose) {
          _logger.verbose('......replacing $k with $v');
        }

        if (rx == null) {
          newText = text.replaceAll(k, v);
        }
        else {
          newText = rx.replace(text, v.toString());
        }

        if ((newText.length != text.length) || (newText != text)) {
          isDone = false;
        }

        text = newText;
      });

      if (_logger.isVerbose) {
        _logger.verbose('......result of expansion:\n\n$text');
      }
    }

    if (_logger.isVerbose) {
      _logger.verbose('......text expansion completed');
    }

    if (isStdOut) {
      if (_logger.isVerbose) {
        _logger.verbose('...writing result to ${StringExt.stdoutDisplay}');
      }
      _logger.out(text);

      tmpFile = null;
    }
    else {
      var inpFilePath = inpFile?.path ?? '';

      var inpDirName = Path.dirname(inpFilePath);
      var inpFileName = Path.basename(inpFilePath);

      var outDirName = Path.dirname(outFilePath);
      var outFileName = Path.basename(outFilePath);

      if (Path.equals(inpFileName, outFileName)) {
        outFileName = inpFileName;
      }

      if (Path.equals(inpDirName, outDirName)) {
        outDirName = inpDirName;
      }

      outFilePath = Path.join(outDirName, outFileName);

      var outDir = Path.fileSystem.directory(outDirName);

      if (!outDir.existsSync()) {
        if (_logger.isVerbose) {
          _logger.verbose('...creating directory ${outDir.path}');
        }
        outDir.createSync(recursive: true);
      }

      if (Path.fileSystem.directory(outFilePath).existsSync()) {
        outFileName = (inpFilePath.startsWith(curDirName) ? inpFilePath.substring(curDirName.length) : Path.basename(inpFilePath));

        var rootPrefixLen = Path.rootPrefix(outFileName).length;

        if (rootPrefixLen > 0) {
          outFileName = outFileName.substring(rootPrefixLen);
        }

        outFilePath = Path.join(outFilePath, outFileName);
      }

      if (tmpFile == null) {
        if (_logger.isVerbose) {
          _logger.verbose('...writing result to $outFilePath');
        }

        Path.fileSystem.file(outFilePath)
          .writeAsStringSync(text);

        if (permissions != null) {
          Command.chmod(permissions.mode, outFilePath);
        }
      }
      else {
        tmpFile = Path.fileSystem.file(tmpFilePath);

        if (_logger.isVerbose) {
          _logger.verbose('...writing result to temp file ${tmpFile.path}');
        }

        tmpFile
          ..deleteIfExistsSync()
          ..writeAsStringSync(text);

        if (permissions != null) {
          Command.chmod(permissions.mode, tmpFile.path);
        }

        if (Path.equals(inpFilePath, outFilePath)) {
          if (_logger.isVerbose) {
            _logger.verbose('...renaming temp file to $outFilePath');
          }
          tmpFile.renameSync(outFilePath);
        }
      }
    }

    if (_logger.isVerbose) {
      _logger.verbose('...completed expanding patterns in the content');
    }

    return (isExpandContentOnly ? null : tmpFile);
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandInpNames(String value, FlatMap map) {
    String inpParamName;
    var result = value;

    for (var i = 0, n = _inpParamNames.length; i < n; i++) {
      inpParamName = _inpParamNames[i];
      result = result.replaceAll(inpParamName, (map[inpParamName] ?? ''));
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  FlatMap expandMap(FlatMap map, String curDirName, String inpFilePath) {
    var newMap = FlatMap();
    newMap.add(map);

    var paramNameCurDir = _config.keywords.forCurDir;
    var paramNameInp = _config.keywords.forInp;

    newMap.forEach((k, v) {
      if (k.isBlank()) {
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
    if (isStdIn || (isExpandContentOnly && !Path.equals(inpFilePath, outFilePath)) || !canExpandContent) {
      return inpFilePath;
    }
    else if (!isStdOut) {
      if (outFilePath.isBlank()) {
        return '';
      }
      else {
        var tmpFileName = (Path.basenameWithoutExtension(outFilePath) +
            fileTypeTmp + Path.extension(inpFilePath));
        var tmpDirName = Path.dirname(outFilePath);

        return Path.join(tmpDirName, tmpFileName);
      }
    }
    else {
      return inpFilePath;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String getCurDirName(FlatMap map, bool canReplace) {
    var curDirName = (getValue(map, key: _config.keywords.forCurDir, canReplace: canReplace));
    curDirName = (curDirName.isBlank() ? Path.currentDirectoryName : Path.getFullPath(curDirName));

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getDirList(String pattern) => DirectoryExt.pathListExSync(pattern);

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getInpFilePaths(String filePath, String curDirName) {
    if (filePath.isBlank()) {
      return [ filePath ]; // ensure at least one pass in a loop
    }

    var filePathTrim = filePath.trim();

    var lst = <String>[];

    if (filePath == StringExt.stdinPath) {
      lst.add(filePath);
    }
    else {
      if (!Path.isAbsolute(filePathTrim)) {
        filePathTrim = Path.getFullPath(Path.join(curDirName, filePathTrim));
      }

      lst = getDirList(filePathTrim);
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: $filePath');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getValue(FlatMap map, {String? key, String? value, required bool canReplace}) {
    if ((value == null) && (key != null) && map.containsKey(key)) {
      value = map[key];
    }

    var isKeyCurDir = key?.startsWith(_config.keywords.forCurDir) ?? false;

    if (canReplace && (value != null) && !value.isBlank()) {
      for (String? oldValue; (oldValue != value); ) {
        oldValue = value;

        map.forEach((k, v) {
          if ((k != key) && !k.isBlank()) {
            value = value?.replaceAll(k, v);

            if (isPathKey(k)) {
              value = Path.adjust(value);
            }
          }
        });
      }

      if ((key != null) && (value?.contains(key) ?? false) && map.containsKey(key)) {
        value = value?.replaceAll(key, map[key] ?? '');

        if (isPathKey(key)) {
          value = Path.adjust(value);
        }
      }

      if (isKeyCurDir) {
        value = Path.getFullPath(value);
        map[key ?? ''] = value ?? '';
      }
    }

    if (!isKeyCurDir && (value?.contains(_config.keywords.forCurDir) ?? false)) {
      value = value?.replaceAll(_config.keywords.forCurDir, curDirName);
    }

    return (value ?? '');
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isPathKey(String key) {
    if (_config.keywords.allForPath.contains(key)) {
      return true;
    }

    if ((rexDetectPaths != null) && rexDetectPaths!.hasMatch(key)) {
      return true;
    }

    return false;
 }

  //////////////////////////////////////////////////////////////////////////////

}