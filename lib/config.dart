import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as Path;
import 'log.dart';
import 'options.dart';
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
  static String PARAM_NAME_INP = '{inp}';
  static String PARAM_NAME_INP_DIR = '{inp-dir}';
  static String PARAM_NAME_INP_EXT = '{inp-ext}';
  static String PARAM_NAME_INP_NAME = '{inp-name}';
  static String PARAM_NAME_OUT = '{out}';

  static final RegExp RE_PARAM_NAME = RegExp('[\\{][^\\{\\}]+[\\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static int lastModifiedInMicrosecondsSinceEpoch;

  //////////////////////////////////////////////////////////////////////////////

  static void addFlatMapsToList(List<Map<String, String>> listOfMaps, Map<String, Object> map) {
    var cloneMap = <String, Object>{};
    cloneMap.addAll(map);

    var isMapFlat = true;

    map.forEach((k, v) {
      if ((v == null) || !isMapFlat /* only one List or Map per call */) {
        return;
      }

      if (v is List) {
        isMapFlat = false;
        addFlatMapsToList_addList(listOfMaps, cloneMap, k, v);
      }
      else if (v is Map) {
        isMapFlat = false;
        addFlatMapsToList_addMap(listOfMaps, cloneMap, k, v);
      }
      else {
        cloneMap[k] = v;
      }
    });

    if (isMapFlat) {
      var strStrMap = <String, String>{};

      cloneMap.forEach((k, v) {
        if (v != null) {
          strStrMap[k] = v.toString();
        }
      });

      strStrMap.forEach((k, v) {
        if (v != null) {
          strStrMap[k] = expandValue(strStrMap[k], strStrMap, paramName: k);
        }
      });

      listOfMaps.add(strStrMap);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addFlatMapsToList_addList(List<Map<String, String>> listOfMaps, Map<String, Object> map, String key, List<Object> argList) {
    var cloneMap = <String, Object>{};
    cloneMap.addAll(map);

    for (var i = 0, n = argList.length; i < n; i++) {
      cloneMap[key] = argList[i];
      addFlatMapsToList(listOfMaps, cloneMap);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addFlatMapsToList_addMap(List<Map<String, String>> listOfMaps, Map<String, Object> map, String key, Map<String, Object> argMap) {
    var cloneMap = <String, Object>{};

    cloneMap.addAll(map);
    cloneMap.remove(key);
    cloneMap.addAll(argMap);

    addFlatMapsToList(listOfMaps, cloneMap);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addMapsToList(List<Map<String, String>> listOfMaps, Map<String, Object> map) {
    var isReady = ((map != null) && map.containsKey(PARAM_NAME_INP) && map.containsKey(PARAM_NAME_OUT));

    if (isReady) {
      addFlatMapsToList(listOfMaps, map);
      map.remove(PARAM_NAME_OUT);
    }
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

      var params = <String, Object>{};
      params[PARAM_NAME_CUR_DIR] = '';

      var action = all[CFG_ACTION];
      assert(action is List);

      var result = <Map<String, String>>[];

      action.forEach((map) {
        assert(map is Map);

        Log.debug('');

        map.forEach((key, value) {
          if (!StringExt.isNullOrBlank(key)) {
            Log.debug('...${key}: ${value}');

            params[key] = (value ?? StringExt.EMPTY);
          }
        });

        if (params.isNotEmpty) {
          Log.debug('...adding to the list of actions');
          addMapsToList(result, params);
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

  static String getFullCurDirName(String curDirName) {
    return Path.join(Options.startDirName, curDirName).getFullPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  static String expandValue(String value, Map<String, Object> map, {String paramName, bool isForAny = false}) {
    var canExpandEnv = (map.containsKey(PARAM_NAME_EXP_ENV) ? StringExt.parseBool(map[PARAM_NAME_EXP_ENV]) : false);
    var hasParamName = !StringExt.isNullOrBlank(paramName);
    var isCurDirParam = (hasParamName && (paramName == PARAM_NAME_CUR_DIR));

    if (canExpandEnv) {
      value = value.expandEnvironmentVariables();
    }

    if (!isForAny && hasParamName) {
      if ((paramName == PARAM_NAME_CMD) || (paramName == PARAM_NAME_INP) || (paramName == PARAM_NAME_OUT)) {
        return value;
      }
    }

    var inputFilePath = map[PARAM_NAME_INP].toString();

    if (inputFilePath == StringExt.STDIN_PATH) {
      if (value.contains(PARAM_NAME_INP_DIR) ||
          value.contains(PARAM_NAME_INP_EXT) ||
          value.contains(PARAM_NAME_INP_NAME)) {
        throw Exception('You can\'t use input file path elements with ${StringExt.STDIN_DISP}');
      }
    }
    else if (!inputFilePath.containsWildcards()) {
      var inputFilePart = Path.dirname(inputFilePath);
      value = value.replaceAll(PARAM_NAME_INP_DIR, inputFilePart);

      inputFilePart = Path.basenameWithoutExtension(inputFilePath);
      value = value.replaceAll(PARAM_NAME_INP_NAME, inputFilePart);

      inputFilePart = Path.extension(inputFilePath);
      value = value.replaceAll(PARAM_NAME_INP_EXT, inputFilePart);
    }

    for (var i = 0; ((i < MAX_EXPANSION_ITERATIONS) && RE_PARAM_NAME.hasMatch(value)); i++) {
      map.forEach((k, v) {
        if (!hasParamName || (k != paramName)) {
          value = value.replaceAll(k, v);
        }
      });
    }

    if (isCurDirParam) {
      value = getFullCurDirName(value);
    }

    if (isParamWithPath(paramName)) {
      value = value.getFullPath();
    }

    return value;
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

      lastModifiedInMicrosecondsSinceEpoch = file.lastModifiedSync().microsecondsSinceEpoch;
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
      else if (k == PARAM_NAME_OUT) {
        PARAM_NAME_OUT = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
