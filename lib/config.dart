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

  //static final int MAX_EXPANSION_ITERATIONS = 10;

  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedMcsec;

  String paramNameCmd = '{cmd}';
  String paramNameCurDir = '{cur-dir}';
  String paramNameExpEnv = '{exp-env}';
  String paramNameExpInp = '{exp-inp}';
  String paramNameInp = '{inp}';
  String paramNameInpDir = '{inp-dir}';
  String paramNameInpExt = '{inp-ext}';
  String paramNameInpName = '{inp-name}';
  String paramNameInpNameExt = '{inp-name-ext}';
  String paramNameInpPath = '{inp-path}';
  String paramNameInpSubDir = '{inp-sub-dir}';
  String paramNameInpSubPath = '{inp-sub-path}';
  String paramNameImport = '{import}';
  String paramNameOut = '{out}';

  //////////////////////////////////////////////////////////////////////////////

  void addFlatMapsToList(List<Map<String, String>> listOfMaps, Map<String, Object> map) {
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

  void addFlatMapsToList_addList(List<Map<String, String>> listOfMaps, Map<String, Object> map, String key, List<Object> argList) {
    var cloneMap = <String, Object>{};
    cloneMap.addAll(map);

    for (var i = 0, n = argList.length; i < n; i++) {
      cloneMap[key] = argList[i];
      addFlatMapsToList(listOfMaps, cloneMap);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void addFlatMapsToList_addMap(List<Map<String, String>> listOfMaps, Map<String, Object> map, String key, Map<String, Object> argMap) {
    var cloneMap = <String, Object>{};

    cloneMap.addAll(map);
    cloneMap.remove(key);
    cloneMap.addAll(argMap);

    addFlatMapsToList(listOfMaps, cloneMap);
  }

  //////////////////////////////////////////////////////////////////////////////

  void addMapsToList(List<Map<String, String>> listOfMaps, Map<String, Object> map) {
    var isReady = ((map != null) && deepContainsKeys(map, [paramNameInp, paramNameOut]));

    if (isReady) {
      addFlatMapsToList(listOfMaps, map);
      map.remove(paramNameOut);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool deepContainsKeys(Map<String, Object> map, List<String> keys, {Map<String, bool> isFound}) {
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

  List<Map<String, String>> exec(List<String> args) {
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
      params[paramNameCurDir] = '';

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

  String getFullCurDirName(String curDirName) {
    return Path.join(Options.startDirName, curDirName).getFullPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandValue(String value, Map<String, Object> map, {String paramName, bool isForAny = false}) {
    var canExpandEnv = (map.containsKey(paramNameExpEnv) ? StringExt.parseBool(map[paramNameExpEnv]) : false);
    //var hasParamName = !StringExt.isNullOrBlank(paramName);
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
    if (paramName == paramNameCurDir) {
      if (Directory(value).existsSync()) {
        value = value.getFullPath();
      }
    }

//    if (hasParamName && value.contains(paramName)) {
//      throw Exception('Circular reference: "${paramName}" => "${value}"');
//    }

    return value;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isParamWithPath(String paramName) {
    return (
        (paramName == paramNameCurDir) ||
        (paramName == paramNameInp) ||
        (paramName == paramNameOut)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object> loadConfigSync() {
    var lf = LoadedFile().loadJsonSync(Options.configFilePath, paramNameImport: paramNameImport);

    lastModifiedMcsec = lf.lastModifiedMcsec;

    if (lf.data is Map) {
      return (lf.data as Map).values.toList()[0];
    }
    else {
      return lf.data;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setActualParamNames(Map<String, Object> renames) {
    renames.forEach((k, v) {
      if (k == paramNameCmd) {
        paramNameCmd = v;
      }
      else if (k == paramNameCurDir) {
        paramNameCurDir = v;
      }
      else if (k == paramNameExpEnv) {
        paramNameExpEnv = v;
      }
      else if (k == paramNameExpInp) {
        paramNameExpInp = v;
      }
      else if (k == paramNameInp) {
        paramNameInp = v;
      }
      else if (k == paramNameInpDir) {
        paramNameInpDir = v;
      }
      else if (k == paramNameInpExt) {
        paramNameInpExt = v;
      }
      else if (k == paramNameInpName) {
        paramNameInpName = v;
      }
      else if (k == paramNameInpNameExt) {
        paramNameInpNameExt = v;
      }
      else if (k == paramNameInpPath) {
        paramNameInpPath = v;
      }
      else if (k == paramNameInpSubDir) {
        paramNameInpSubDir = v;
      }
      else if (k == paramNameInpSubPath) {
        paramNameInpSubPath = v;
      }
      else if (k == paramNameImport) {
        paramNameImport = v;
      }
      else if (k == paramNameOut) {
        paramNameOut = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
