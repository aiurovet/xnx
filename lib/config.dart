import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'log.dart';
import 'options.dart';
import 'ext/directory.dart';
import 'ext/string.dart';

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

  static final String CMD_EXPAND = 'expand-only';

  static final int MAX_EXPANSION_ITERATIONS = 10;

  static String PARAM_NAME_COMMAND = '{command}';
  static String PARAM_NAME_HEIGHT = '{height}';
  static String PARAM_NAME_INPUT = '{input}';
  static String PARAM_NAME_INPUT_FILE_DIR = '{input-file-dir}';
  static String PARAM_NAME_INPUT_FILE_EXT = '{input-file-ext}';
  static String PARAM_NAME_INPUT_FILE_NAME = '{input-file-name}';
  static String PARAM_NAME_OUTPUT = '{output}';
  static String PARAM_NAME_EXPAND_ENV = '{expand-environment}';
  static String PARAM_NAME_EXPAND_INP = '{expand-input}';
  static String PARAM_NAME_TOPDIR = '{topDir}';
  static String PARAM_NAME_WIDTH = '{width}';

  static final RegExp RE_PARAM_NAME = RegExp('[\\{][^\\{\\}]+[\\}]', caseSensitive: false);
  static final RegExp RE_PATH_LIST_SEP = RegExp('\\s*,\\s*');

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> params;

  //////////////////////////////////////////////////////////////////////////////

  static void addParamValue(String key, Object value) {
    if (StringExt.isNullOrEmpty(key)) {
      return;
    }

    var strValue = StringExt.EMPTY;

    if (value != null) {
      assert(!(value is List));
      assert(!(value is Map));

      strValue = value.toString().trim();
    }

    params[key] = strValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<Map<String, String>> exec(List<String> args) {
    Options.parseArgs(args);

    var text = readSync();
    var decoded = jsonDecode(text);
    assert(decoded is Map);

    Log.information('Processing configuration data');

    var all = decoded.values.toList()[0];

    if (all is Map) {
      var rename = all[CFG_RENAME];

      Log.information('Processing renames');

      if (rename is Map) {
        setActualParamNames(rename);
      }

      Log.information('Processing actions');

      params = {};
      params[PARAM_NAME_TOPDIR] = '';

      var action = all[CFG_ACTION];
      assert(action is List);

      var result = List<Map<String, String>>();

      action.forEach((map) {
        assert(map is Map);

        Log.debug('');

        map.forEach((key, value) {
          if (!StringExt.isNullOrBlank(key)) {
            Log.debug('...${key}: ${value}');
            addParamValue(key, value);
          }
        });

        if (params.length > 0) {
          Log.debug('...adding to the list of actions');
          expandParamValuesAndAddToList(result);
        }

        Log.debug('...completed row processing');
      });

      Log.information('\nAdded ${result.length} commands\n');

      return result;
    }
    else {
      Log.information('No command added');

      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String expandParamValue(String paramName, {bool isForAny = false}) {
    var paramValue = (params[paramName] ?? StringExt.EMPTY);

    var canExpandEnv = (params.containsKey(PARAM_NAME_EXPAND_ENV) ? StringExt.parseBool(params[PARAM_NAME_EXPAND_ENV]) : false);

    if (canExpandEnv) {
      paramValue = paramValue.expandEnvironmentVariables();
    }

    if (!isForAny) {
      if ((paramName == PARAM_NAME_COMMAND) || (paramName == PARAM_NAME_OUTPUT)) {
        return paramValue;
      }
    }

    var inputFilePath = params[PARAM_NAME_INPUT];

    var inputFilePart = path.dirname(inputFilePath);
    paramValue = paramValue.replaceAll(PARAM_NAME_INPUT_FILE_DIR, inputFilePart);

    inputFilePart = path.basenameWithoutExtension(inputFilePath);
    paramValue = paramValue.replaceAll(PARAM_NAME_INPUT_FILE_NAME, inputFilePart);

    inputFilePart = path.extension(inputFilePath);
    paramValue = paramValue.replaceAll(PARAM_NAME_INPUT_FILE_EXT, inputFilePart);

    for (var i = 0; ((i < MAX_EXPANSION_ITERATIONS) && RE_PARAM_NAME.hasMatch(paramValue)); i++) {
      params.forEach((k, v) {
        if (k != paramName) {
          paramValue = paramValue.replaceAll(k, v);
        }
      });
    }

    if (paramName == PARAM_NAME_TOPDIR) {
      if (!path.isAbsolute(paramValue)) {
        paramValue = path.join(Options.startDirName, paramValue);
        Directory.current = paramValue.getFullPath();
      }
    }

    if (isParamWithPath(paramName)) {
      paramValue = paramValue.getFullPath();
    }

    return paramValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void expandParamValuesAndAddToList(List<Map<String, String>> lst) {
    if (!hasMinKnownParams()) {
      return;
    }

    var newParams = <String, String>{};

    params.forEach((k, v) {
      if (k != PARAM_NAME_COMMAND) {
        newParams[k] = expandParamValue(k, isForAny: false);
      }
    });

    params.addAll(newParams);

    var listOfInpFilePaths = getListOfInpFilePaths();

    for (var inpFilePath in listOfInpFilePaths) {
      var oldInpFilePath = params[PARAM_NAME_INPUT];
      var oldOutFilePath = params[PARAM_NAME_OUTPUT];

      newParams = <String, String>{};
      newParams.addAll(params);

      newParams[PARAM_NAME_INPUT] = inpFilePath;
      params[PARAM_NAME_INPUT] = inpFilePath;

      newParams[PARAM_NAME_OUTPUT] = expandParamValue(PARAM_NAME_OUTPUT, isForAny: true);
      params[PARAM_NAME_OUTPUT] = newParams[PARAM_NAME_OUTPUT];

      var command = expandParamValue(PARAM_NAME_COMMAND, isForAny: true);

      params[PARAM_NAME_INPUT] = oldInpFilePath;
      params[PARAM_NAME_OUTPUT] = oldOutFilePath;

      if (StringExt.isNullOrBlank(command)) {
        throw Exception(
          'Command is not defined for the output file "${params[PARAM_NAME_OUTPUT]}". Did you miss { "${PARAM_NAME_COMMAND}": "${CMD_EXPAND}" }?');
      }

      newParams[PARAM_NAME_COMMAND] = command;
      lst.add(newParams);
    }

    removeMinKnownParams();
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getListOfInpFilePaths() {
    var filePaths = params[PARAM_NAME_INPUT].split(RE_PATH_LIST_SEP);
    var lstAll = <String>[];

    for (var filePath in filePaths) {
      var dir = Directory(filePath);
      List<String> lstCur;

      var pattern = path.basename(filePath);

      if (pattern.containsWildcards()) {
        var parentDirName = path.dirname(filePath);
        var hasParentDir = !StringExt.isNullOrBlank(parentDirName);

        if (hasParentDir) {
          if (!path.isAbsolute(parentDirName)) {
            parentDirName = path.join(filePath, parentDirName);
          }

          dir = Directory(parentDirName);
        }

        lstCur = dir.pathListSync(pattern: pattern,
            checkExists: false,
            recursive: hasParentDir,
            takeDirs: false,
            takeFiles: true);
      }
      else if (dir.existsSync()) {
        lstCur = dir.pathListSync(pattern: null, checkExists: false, recursive: true, takeDirs: false, takeFiles: true);
      }
      else {
        var file = File(filePath);

        if (file.existsSync()) {
          lstCur = [file.path];
        }
      }

      if ((lstCur?.length ?? 0) > 0) {
        lstAll.addAll(lstCur);
      }
      else {
        throw Exception('No input found for: ${filePaths}');
      }
    }

    return lstAll;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool hasMinKnownParams() {
    var hasInput = params.containsKey(PARAM_NAME_INPUT);
    var hasOutput = params.containsKey(PARAM_NAME_OUTPUT);

    return (hasInput && hasOutput);
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isParamWithPath(String paramName) {
    return (
        (paramName == PARAM_NAME_INPUT) ||
        (paramName == PARAM_NAME_OUTPUT)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getParamValue(Map<String, String> map, String paramName) {
    if (map.containsKey(paramName)) {
      return map[paramName];
    }
    else {
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String readSync() {
    var inpPath = Options.configFilePath;
    var isStdIn = (inpPath == Options.PATH_STDIN);
    var inpName = (isStdIn ? '<stdin>' : '"' + inpPath + '"');

    Log.information('Reading configuration from ${inpName}');

    String text;

    if (isStdIn) {
      text = readInputSync();
    }
    else {
      var file = File(inpPath);

      if (!file.existsSync()) {
        throw Exception('Failed to find expected configuration file: ${inpName}');
      }

      text = file.readAsStringSync();
    }

    return text;
  }

  static String readInputSync() {
    final input = [];

    for (var isEmpty = true; ; isEmpty = false) {
      var byte = stdin.readByteSync();

      if (byte < 0) {
        if (isEmpty) {
          return null;
        }

        break;
      }

      input.add(byte);
    }

    return utf8.decode(input, allowMalformed: true);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void removeMinKnownParams() {
    params.removeWhere((k, v) => (
      (k == PARAM_NAME_WIDTH) ||
      (k == PARAM_NAME_HEIGHT) ||
      (k == PARAM_NAME_OUTPUT)
    ));
  }

  //////////////////////////////////////////////////////////////////////////////

  static void setActualParamNames(Map<String, Object> renames) {
    renames.forEach((k, v) {
      if (k == PARAM_NAME_COMMAND) {
        PARAM_NAME_COMMAND = v;
      }
      else if (k == PARAM_NAME_HEIGHT) {
        PARAM_NAME_HEIGHT = v;
      }
      else if (k == PARAM_NAME_INPUT) {
        PARAM_NAME_INPUT = v;
      }
      else if (k == PARAM_NAME_INPUT_FILE_DIR) {
        PARAM_NAME_INPUT_FILE_DIR = v;
      }
      else if (k == PARAM_NAME_INPUT_FILE_EXT) {
        PARAM_NAME_INPUT_FILE_EXT = v;
      }
      else if (k == PARAM_NAME_INPUT_FILE_NAME) {
        PARAM_NAME_INPUT_FILE_NAME = v;
      }
      else if (k == PARAM_NAME_OUTPUT) {
        PARAM_NAME_OUTPUT = v;
      }
      else if (k == PARAM_NAME_EXPAND_ENV) {
        PARAM_NAME_EXPAND_ENV = v;
      }
      else if (k == PARAM_NAME_EXPAND_INP) {
        PARAM_NAME_EXPAND_INP = v;
      }
      else if (k == PARAM_NAME_TOPDIR) {
        PARAM_NAME_TOPDIR = v;
      }
      else if (k == PARAM_NAME_WIDTH) {
        PARAM_NAME_WIDTH = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
