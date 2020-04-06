import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'log.dart';
import 'options.dart';
import 'ext/directory.dart';
import 'ext/stdin.dart';
import 'ext/string.dart';

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

  static final String CMD_EXPAND = 'expand-only';

  static final int MAX_EXPANSION_ITERATIONS = 10;

  static String PARAM_NAME_CMD = '{cmd}';
  static String PARAM_NAME_CUR_DIR = '{cur-dir}';
  static String PARAM_NAME_EXP_ENV = '{exp-env}';
  static String PARAM_NAME_EXP_INP = '{exp-inp}';
  static String PARAM_NAME_FLD_SEP = '{fld-sep}';
  static String PARAM_NAME_INP = '{inp}';
  static String PARAM_NAME_INP_DIR = '{inp-dir}';
  static String PARAM_NAME_INP_EXT = '{inp-ext}';
  static String PARAM_NAME_INP_NAME = '{inp-name}';
  static String PARAM_NAME_LST_SEP = '{lst-sep}';
  static String PARAM_NAME_OUT = '{out}';

  static final RegExp RE_PARAM_NAME = RegExp('[\\{][^\\{\\}]+[\\}]', caseSensitive: false);
  static final RegExp RE_PATH_LIST_SEP = RegExp('\\s*,\\s*');

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static Map<String, Object> params;

  //////////////////////////////////////////////////////////////////////////////

  static void addFlatMapsToList(List<Map<String, Object>> lst, Map<String, Object> map) {
    var mapOfLists = <String, List<String>>{};

    map.forEach((k, v) {
      var isNameInp = (k == PARAM_NAME_INP);

      if (isNameInp) {
        lst.addAll(getListOfInpFilePaths(vv));
      }
      else if (canSplit) {
        lst.addAll(vv);
      }
      else {
        lst.add(v);
      }

      mapOfLists[k] = lst;
    });

    addMapsToList(lst, mapOfLists, null);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addMapsToList(List<Map<String, String>> toList, Map<String, List<String>> mapOfLists, Map<String, String> map) {
    var skip = (map?.length ?? 0);

    if (skip < mapOfLists.length) {
      var key = mapOfLists.keys.skip(skip).first;

      if (key != null) {
        var lst = mapOfLists[key];
        var len = lst.length;

        var newMap = <String, String>{};

        if (map != null) {
          newMap.addAll(map);
        }

        for (var i = 0; i < len; i++) {
          newMap[key] = lst[i];
          addMapsToList(toList, mapOfLists, newMap);
        }
      }
    }
    else {
      toList.add(map);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addParamValue(String key, Object value) {
    if (StringExt.isNullOrEmpty(key)) {
      return;
    }

    params[key] = (value ?? StringExt.EMPTY);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addParamsToList(List<Map<String, Object>> lst) {
    if (!params.containsKey(PARAM_NAME_INP) || !params.containsKey(PARAM_NAME_OUT)) {
      return;
    }

    addFlatMapsToList(lst, params);

    params.remove(PARAM_NAME_OUT);
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
      params[PARAM_NAME_CUR_DIR] = '';

      var action = all[CFG_ACTION];
      assert(action is List);

      var result = <Map<String, Object>>[];

      action.forEach((map) {
        assert(map is Map);

        Log.debug('');

        map.forEach((key, value) {
          if (!StringExt.isNullOrBlank(key)) {
            Log.debug('...${key}: ${value}');
            addParamValue(key, value);
          }
        });

        if (params.isNotEmpty) {
          Log.debug('...adding to the list of actions');
          addParamsToList(result);
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

    paramValue = expandValue(paramValue, paramName: paramName, isForAny: isForAny);

    return paramValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String expandValue(String value, {String paramName, bool isForAny = false}) {
    var canExpandEnv = (params.containsKey(PARAM_NAME_EXP_ENV) ? StringExt.parseBool(params[PARAM_NAME_EXP_ENV]) : false);
    var hasParamName = StringExt.isNullOrBlank(paramName);
    var isCurDirParam = (hasParamName && (paramName == PARAM_NAME_CUR_DIR));
    var hasCurDir = isCurDirParam;

    if (canExpandEnv) {
      value = value.expandEnvironmentVariables();
    }

    if (!isForAny && hasParamName) {
      if ((paramName == PARAM_NAME_CMD) || (paramName == PARAM_NAME_OUT)) {
        return value;
      }
    }

    var inputFilePath = params[PARAM_NAME_INP];

    if (inputFilePath == StringExt.STDIN_PATH) {
      if (value.contains(PARAM_NAME_INP_DIR) ||
          value.contains(PARAM_NAME_INP_EXT) ||
          value.contains(PARAM_NAME_INP_NAME)) {
        throw Exception('You can\'t use input file path elements with ${StringExt.STDIN_DISP}');
      }
    }
    else {
      var inputFilePart = path.dirname(inputFilePath);
      value = value.replaceAll(PARAM_NAME_INP_DIR, inputFilePart);

      inputFilePart = path.basenameWithoutExtension(inputFilePath);
      value = value.replaceAll(PARAM_NAME_INP_NAME, inputFilePart);

      inputFilePart = path.extension(inputFilePath);
      value = value.replaceAll(PARAM_NAME_INP_EXT, inputFilePart);
    }

    for (var i = 0; ((i < MAX_EXPANSION_ITERATIONS) && RE_PARAM_NAME.hasMatch(value)); i++) {
      params.forEach((k, v) {
        if (!isCurDirParam && (k == PARAM_NAME_CUR_DIR)) {
          hasCurDir = true;
        }

        if (!hasParamName || (k != paramName)) {
          value = value.replaceAll(k, v);
        }
      });
    }

    if (hasCurDir && !path.isAbsolute(value)) {
      value = path.join(Options.startDirName, value).getFullPath();
    }

    if (isParamWithPath(paramName)) {
      value = value.getFullPath();
    }

    return value;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getCurDirName({Map<String, String> map}) {
    var curDirName = (Config.getValue((map ?? params), PARAM_NAME_CUR_DIR, canExpand: false) ?? StringExt.EMPTY);
    curDirName = curDirName.getFullPath();

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getListOfInpFilePaths(List<String> filePaths) {
    if ((filePaths == null) || filePaths.isEmpty) {
      return [];
    }

    var lstAll = <String>[];

    for (var filePath in filePaths) {
      var filePathTrim = expandValue(filePath.trim(), paramName: null, isForAny: true);

      List<String> lstCur;

      if (filePath == StringExt.STDIN_PATH) {
        lstCur.add(filePath);
      }
      else {
        var parentDirName = path.dirname(filePathTrim);
        var hasParentDir = !StringExt.isNullOrBlank(parentDirName);

        if (!path.isAbsolute(filePathTrim)) {
          filePathTrim = path.join(getCurDirName(), filePathTrim);
          parentDirName = path.dirname(filePathTrim);
        }

        var dir = Directory(filePathTrim);
        var pattern = path.basename(filePathTrim);

        if (pattern.containsWildcards()) {
          if (hasParentDir) {
            dir = Directory(parentDirName);
          }

          lstCur = dir.pathListSync(
              pattern: pattern,
              checkExists: false,
              recursive: hasParentDir,
              takeDirs: false,
              takeFiles: true
          );
        }
        else if (dir.existsSync()) {
          lstCur = dir.pathListSync(
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
            lstCur = [file.path];
          }
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

  static bool isParamWithPath(String paramName) {
    return (
        (paramName == PARAM_NAME_CUR_DIR) ||
        (paramName == PARAM_NAME_INP) ||
        (paramName == PARAM_NAME_OUT)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getValue(Map<String, String> map, String key, {canExpand}) {
    if (map.containsKey(key)) {
      var isCmd = (key == PARAM_NAME_CMD);
      var value = map[key];

      if ((canExpand ?? false) && (value != null)) {
        for (var oldValue = value; ;) {
          map.forEach((k, v) {
            if (k != key) {
              if (!isCmd || ((k != PARAM_NAME_INP) && (k != PARAM_NAME_OUT))) {
                value = value.replaceAll(k, v);
              }
            }
            else if (k == PARAM_NAME_CUR_DIR) {
              value = v.getFullPath();
            }
          });

          if (oldValue == value) {
            break;
          }

          oldValue = value;
        }
      }

      return value;
    }
    else {
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String readSync() {
    var inpPath = Options.configFilePath;
    var isStdIn = (inpPath == StringExt.STDIN_PATH);
    var inpName = (isStdIn ? StringExt.STDIN_DISP : '"' + inpPath + '"');

    Log.information('Reading configuration from ${inpName}');

    String text;

    if (isStdIn) {
      text = stdin.readAsStringSync(endByte: StringExt.EOT_CODE);
    }
    else {
      var file = File(inpPath);

      if (!file.existsSync()) {
        throw Exception('Failed to find expected configuration file: ${inpName}');
      }

      text = file.readAsStringSync();
    }

    text = text.removeJsComments();

    return text;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void setActualParamNames(Map<String, Object> renames) {
    renames.forEach((k, v) {
      if (k == PARAM_NAME_CMD) {
        PARAM_NAME_CMD = v;
      }
      else if (k == PARAM_NAME_CUR_DIR) {
        PARAM_NAME_CUR_DIR = v;
      }
      else if (k == PARAM_NAME_EXP_ENV) {
        PARAM_NAME_EXP_ENV = v;
      }
      else if (k == PARAM_NAME_EXP_INP) {
        PARAM_NAME_EXP_INP = v;
      }
      else if (k == PARAM_NAME_INP) {
        PARAM_NAME_INP = v;
      }
      else if (k == PARAM_NAME_INP_DIR) {
        PARAM_NAME_INP_DIR = v;
      }
      else if (k == PARAM_NAME_INP_EXT) {
        PARAM_NAME_INP_EXT = v;
      }
      else if (k == PARAM_NAME_INP_NAME) {
        PARAM_NAME_INP_NAME = v;
      }
      else if (k == PARAM_NAME_LST_SEP) {
        PARAM_NAME_LST_SEP = v;
      }
      else if (k == PARAM_NAME_OUT) {
        PARAM_NAME_OUT = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
