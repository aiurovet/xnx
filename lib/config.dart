import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

import 'ext/string.dart';

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String APP_NAME = 'doul';
  static final String FILE_TYPE_CFG = '.json';
  static final String DEF_FILE_NAME = '${APP_NAME}${FILE_TYPE_CFG}';

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

  static final int MAX_EXPANSION_ITERATIONS = 10;

  static String PARAM_NAME_COMMAND = '{command}';
  static String PARAM_NAME_HEIGHT = '{height}';
  static String PARAM_NAME_INPUT = '{input}';
  static String PARAM_NAME_OUTPUT = '{output}';
  static String PARAM_NAME_RESIZE = '{resize}';
  static String PARAM_NAME_TOPDIR = '{topDir}';
  static String PARAM_NAME_WIDTH = '{width}';

  static final RegExp RE_PARAM_NAME = RegExp('[\\{][^\\{\\}]+[\\}]', caseSensitive: false);
  static final RegExp RE_PATH_SEP = RegExp('[\\/\\\\]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static String filePath;
  static Map<String, String> params;
  static String topDirName;

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

  static Future<List<Map<String, String>>> exec(List<String> args) async {
    parseArgs(args);

    var file = new File(filePath);

    if (!(await file.exists())) {
      throw new Exception('No configuration file found: "${filePath}"');
    }

    var text = await file.readAsString();

    var decoded = jsonDecode(text);
    assert(decoded is Map);

    var all = decoded.values.toList()[0];

    if (all is Map) {
      var rename = all[CFG_RENAME];

      if (rename is Map) {
        setActualParamNames(rename);
      }

      params = Map();
      params[PARAM_NAME_TOPDIR] = '';

      var action = all[CFG_ACTION];
      assert(action is List);

      var result = List<Map<String, String>>();

      action.forEach((map) {
        assert(map is Map);

        map.forEach((key, value) {
          addParamValue(key, value);
        });

        expandParamValuesAndAddToList(result);
      });

      return result;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String expandParamValue(String paramName, {bool isForAny = false}) {
    var paramValue = params[paramName];

    for (var i = 0; ((i < MAX_EXPANSION_ITERATIONS) && RE_PARAM_NAME.hasMatch(paramValue)); i++) {
      params.forEach((k, v) {
        if ((k != paramName) && (isForAny || (k != PARAM_NAME_COMMAND))) {
          if ((paramName != PARAM_NAME_COMMAND) || (k != PARAM_NAME_INPUT)) {
            paramValue = paramValue.replaceAll(k, v);
          }
        }
      });
    }

    if (isParamWithPath(paramName)) {
      paramValue = getFullPath(paramValue);
    }

    return paramValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void expandParamValuesAndAddToList(List<Map<String, String>> lst) {
    if (!hasMinKnownParams()) {
      return;
    }
    
    var newParams = Map<String, String>();

    params.forEach((k, v) {
      if (k != PARAM_NAME_COMMAND) {
        newParams[k] = expandParamValue(k, isForAny: false);
      }
    });

    params.addAll(newParams);
    newParams[PARAM_NAME_COMMAND] = expandParamValue(PARAM_NAME_COMMAND, isForAny: true);

    lst.add(newParams);

    removeMinKnownParams();
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getFullPath(String path) {
    var full = (path == null ? StringExt.EMPTY : path.replaceAll(RE_PATH_SEP, Platform.pathSeparator));
    full = canonicalize(full);

    return full;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool hasMinKnownParams() {
    var hasCommand = params.containsKey(PARAM_NAME_COMMAND);
    var hasInput = params.containsKey(PARAM_NAME_INPUT);
    var hasOutput = params.containsKey(PARAM_NAME_OUTPUT);
    var hasWidth = params.containsKey(PARAM_NAME_WIDTH);
    var hasHeight = params.containsKey(PARAM_NAME_HEIGHT);

    var hasKeys = (hasCommand && hasInput && hasOutput && hasWidth && hasHeight);

    return hasKeys;
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

  static void parseArgs(List<String> args) {
    var errMsg = StringExt.EMPTY;
    var isHelp = false;

    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', help: 'this help screen', negatable: false, callback: (value) {
        isHelp = value;
      })
      ..addOption('top-dir', abbr: 'd', help: 'top directory to resolve paths from', valueHelp: 'DIR', defaultsTo: 'the current directory', callback: (value) {
        topDirName = value;
      })
      ..addOption('config', abbr: 'c', help: 'configuration file in json format', valueHelp: 'FILE', defaultsTo: '<DIR${Platform.pathSeparator}${DEF_FILE_NAME}>', callback: (value) {
        filePath = value;
      })
    ;

    try {
      parser.parse(args);
    }
    catch (e) {
      isHelp = true;
      errMsg = e.message;
    }

    if (!isHelp) {
      if (StringExt.isNullOrBlank(topDirName)) {
        topDirName = null;
      }

      topDirName = canonicalize(topDirName ?? '');

      Directory.current = topDirName;

      if (StringExt.isNullOrBlank(filePath)) {
        filePath = DEF_FILE_NAME;
      }

      if (StringExt.isNullOrBlank(extension(filePath))) {
        filePath = setExtension(filePath, FILE_TYPE_CFG);
      }

      if (!isAbsolute(filePath)) {
        filePath = canonicalize(join(topDirName, filePath));
      }
    }

    if (isHelp) {
      print('''

USAGE:

${APP_NAME} [OPTIONS]

${parser.usage}
      ''');

      throw new Exception(errMsg);
    }
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
      else if (k == PARAM_NAME_OUTPUT) {
        PARAM_NAME_OUTPUT = v;
      }
      else if (k == PARAM_NAME_RESIZE) {
        PARAM_NAME_RESIZE = v;
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
