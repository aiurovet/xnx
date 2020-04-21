import 'dart:io';

import 'package:path/path.dart' as Path;
import 'loaded_file.dart';
import 'log.dart';
import 'options.dart';
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
  static String PARAM_NAME_INP_NAME_EXT = '{inp-name-ext}';
  static String PARAM_NAME_INP_PATH = '{inp-path}';
  static String PARAM_NAME_INP_SUB_DIR = '{inp-sub-dir}';
  static String PARAM_NAME_INP_SUB_PATH = '{inp-sub-path}';
  static String PARAM_NAME_IMPORT = '{import}';
  static String PARAM_NAME_OUT = '{out}';

  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static int lastModifiedMcsec;

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
        strStrMap[k] = v.toString();
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
    var isReady = ((map != null) && deepContainsKeys(map, [PARAM_NAME_INP, PARAM_NAME_OUT]));

    if (isReady) {
      addFlatMapsToList(listOfMaps, map);
      map.remove(PARAM_NAME_OUT);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool deepContainsKeys(Map<String, Object> map, List<String> keys, {Map<String, bool> isFound}) {
    if ((map == null) || (keys == null)) {
      return false;
    }

    var isFoundAll = false;

    if (isFound == null) {
      isFound = {};

      for (var i = 0, n = keys.length; i < n; i++) {
        isFound[keys[i]] = false;
      }
    }

    map.forEach((k, v) {
      if (!isFoundAll) {
        if (keys.contains(k)) {
          isFound[k] = true;
        }
        else if (v is List) {
          for (var i = 0, n = v.length; i < n; i++) {
            var vv = v[i];

            if (vv is Map) {
              isFoundAll = deepContainsKeys(vv, keys, isFound: isFound);
            }
          }
        }
        else if (v is Map) {
          isFoundAll = deepContainsKeys(v, keys, isFound: isFound);
        }
      }
    });

    isFoundAll = !isFound.containsValue(false);

    return isFoundAll;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<Map<String, String>> exec(List<String> args) {
    Options.parseArgs(args);

    Log.information('Loading configuration data');

    var all = loadConfigSync();

    Log.information('Processing configuration data');

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

      (action as List).forEach((map) {
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
    //var isCurDirParam = (hasParamName && (paramName == PARAM_NAME_CUR_DIR));

    if (canExpandEnv) {
      value = value.expandEnvironmentVariables();
    }

//    if (!isForAny && hasParamName) {
//      if ((paramName == PARAM_NAME_CMD) || (paramName == PARAM_NAME_INP) || (paramName == PARAM_NAME_OUT)) {
//        return value;
//      }
//    }
//
//    var inputFilePath = map[PARAM_NAME_INP].toString();
//
//    if (inputFilePath == StringExt.STDIN_PATH) {
//      if (value.contains(PARAM_NAME_INP_DIR) ||
//          value.contains(PARAM_NAME_INP_EXT) ||
//          value.contains(PARAM_NAME_INP_PATH) ||
//          value.contains(PARAM_NAME_INP_NAME) ||
//          value.contains(PARAM_NAME_INP_NAME_EXT)) {
//        throw Exception('You can\'t use input file path elements with ${StringExt.STDIN_DISP}');
//      }
//    }
//    else if (!StringExt.isNullOrBlank(inputFilePath) && !Wildcard.isA(inputFilePath)) {
//      var inputFilePart = Path.dirname(inputFilePath);
//      value = value.replaceAll(PARAM_NAME_INP_DIR, inputFilePart);
//
//      inputFilePart = Path.basename(inputFilePath);
//      value = value.replaceAll(PARAM_NAME_INP_NAME_EXT, inputFilePart);
//
//      inputFilePart = Path.basename(inputFilePath);
//      value = value.replaceAll(PARAM_NAME_INP_PATH, inputFilePath);
//
//      inputFilePart = Path.basenameWithoutExtension(inputFilePath);
//      value = value.replaceAll(PARAM_NAME_INP_NAME, inputFilePart);
//
//      inputFilePart = Path.extension(inputFilePath);
//      value = value.replaceAll(PARAM_NAME_INP_EXT, inputFilePart);
//    }
//
//    for (var i = 0; ((i < MAX_EXPANSION_ITERATIONS) && RE_PARAM_NAME.hasMatch(value)); i++) {
//      map.forEach((k, v) {
//        if (!hasParamName || (k != paramName)) {
//          value = value.replaceAll(k, v);
//        }
//      });
//    }
//
//    if (isCurDirParam) {
//      value = getFullCurDirName(value);
//    }
//
    if (paramName == PARAM_NAME_CUR_DIR) {
      if (Directory(value).existsSync()) {
        value = value.getFullPath();
      }
    }

    if (hasParamName && value.contains(paramName)) {
      throw Exception('Circular reference: "${paramName}" => "${value}"');
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
    //var isCmd = (key == PARAM_NAME_CMD);

    if (map.containsKey(key)) {
      var value = map[key];

      if ((canExpand ?? false) && (value != null)) {
        for (var oldValue = value; ;) {
          map.forEach((k, v) {
            if (k != key) {
              if ((k != PARAM_NAME_INP) && (k != PARAM_NAME_OUT)) {
                value = value.replaceAll(k, v);
              }
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

  static Map<String, Object> loadConfigSync() {
    var lf = LoadedFile().loadJsonSync(Options.configFilePath, paramNameImport: PARAM_NAME_IMPORT);

    lastModifiedMcsec = lf.lastModifiedMcsec;

    if (lf.data is Map) {
      return (lf.data as Map).values.toList()[0];
    }
    else {
      return lf.data;
    }
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
      else if (k == PARAM_NAME_INP_NAME_EXT) {
        PARAM_NAME_INP_NAME_EXT = v;
      }
      else if (k == PARAM_NAME_INP_PATH) {
        PARAM_NAME_INP_PATH = v;
      }
      else if (k == PARAM_NAME_INP_SUB_DIR) {
        PARAM_NAME_INP_SUB_DIR = v;
      }
      else if (k == PARAM_NAME_INP_SUB_PATH) {
        PARAM_NAME_INP_SUB_PATH = v;
      }
      else if (k == PARAM_NAME_IMPORT) {
        PARAM_NAME_IMPORT = v;
      }
      else if (k == PARAM_NAME_OUT) {
        PARAM_NAME_OUT = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
