import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

import 'ext/string.dart';
import 'help.dart';

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
  static String PARAM_NAME_EXPAND_ENV = '{expand-env}';
  static String PARAM_NAME_EXPAND_INP = '{expand-inp}';
  static String PARAM_NAME_TOPDIR = '{topDir}';
  static String PARAM_NAME_WIDTH = '{width}';

  static final String PATH_STDIN = '-';
  static final String PATH_PWD = './';

  static final RegExp RE_PARAM_NAME = RegExp('[\\{][^\\{\\}]+[\\}]', caseSensitive: false);
  static final RegExp RE_PATH_SEP = RegExp('[\\/\\\\]', caseSensitive: false);
  static final RegExp RE_PATH_DONE = RegExp('^[\\.\\/\\\\]|[\\:]', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp('^[a-z]+[\:][\\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static String filePath;
  static bool isVerbose;
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

    var text = await read();
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

    var canExpandEnv = (params.containsKey(PARAM_NAME_EXPAND_ENV) ? StringExt.parseBool(params[PARAM_NAME_EXPAND_ENV]) : false);
    var paramValue = (params[paramName] ?? StringExt.EMPTY);

    if (canExpandEnv) {
      paramValue = StringExt.expandEnvironmentVariables(paramValue);
    }

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

  static String getFullPath(String path, {String separator}) {
    String full;
    var prot = StringExt.EMPTY;

    if (StringExt.isNullOrBlank(path)) {
      full = StringExt.EMPTY;
    }
    else {
      var sep = (separator ?? Platform.pathSeparator);
      var match = RE_PROTOCOL.firstMatch(path);

      if ((match != null) && (match.start == 0)) {
        prot = path.substring(0, match.end);
        full = path.substring(match.end);
      }
      else {
        full = path;
      }

      if (!isAbsolute(full)) {
        if (!RE_PATH_DONE.hasMatch(full)) {
          full = PATH_PWD + full;
        }
      }

      full = full.replaceAll(RE_PATH_SEP, sep);
    }
    
    full = prot + canonicalize(full);

    return full;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool hasMinKnownParams() {
    //var hasCommand = params.containsKey(PARAM_NAME_COMMAND);
    var hasInput = params.containsKey(PARAM_NAME_INPUT);
    var hasOutput = params.containsKey(PARAM_NAME_OUTPUT);
    //var hasWidth = params.containsKey(PARAM_NAME_WIDTH);
    //var hasHeight = params.containsKey(PARAM_NAME_HEIGHT);

    var hasKeys = (/*hasCommand &&*/ hasInput && hasOutput /*&& hasWidth && hasHeight*/);

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
    var isHelpAll = false;

    isVerbose = false;

    final parser = ArgParser()
      ..addFlag(Help.OPT_HELP['name'], abbr: Help.OPT_HELP['abbr'], help: Help.OPT_HELP['help'], negatable: Help.OPT_HELP['negatable'], callback: (value) {
        isHelp = value;
      })
      ..addFlag(Help.OPT_HELP_ALL['name'], abbr: Help.OPT_HELP_ALL['abbr'], help: Help.OPT_HELP_ALL['help'], negatable: Help.OPT_HELP_ALL['negatable'], callback: (value) {
        isHelpAll = value;

        if (isHelpAll) {
          isHelp = true;
        }
      })
      ..addOption(Help.OPT_TOPDIR['name'], abbr: Help.OPT_TOPDIR['abbr'], help: Help.OPT_TOPDIR['help'], valueHelp: Help.OPT_TOPDIR['negatable'], callback: (value) {
        topDirName = value;
      })
      ..addOption(Help.OPT_CONFIG['name'], abbr: Help.OPT_CONFIG['abbr'], help: Help.OPT_CONFIG['help'], valueHelp: Help.OPT_CONFIG['negatable'], callback: (value) {
        filePath = value;
      })
      ..addFlag(Help.OPT_VERBOSE['name'], abbr: Help.OPT_VERBOSE['abbr'], help: Help.OPT_VERBOSE['help'], negatable: Help.OPT_VERBOSE['negatable'], callback: (value) {
        isVerbose = value;
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

      if (StringExt.isNullOrBlank(filePath)) {
        filePath = DEF_FILE_NAME;
      }

      if (filePath != PATH_STDIN) {
        if (StringExt.isNullOrBlank(extension(filePath))) {
          filePath = setExtension(filePath, FILE_TYPE_CFG);
        }

        if (!isAbsolute(filePath)) {
          filePath = canonicalize(filePath);
        }
      }

      Directory.current = topDirName;
    }

    if (isHelp) {
      Help.printUsage(parser, isAll: isHelpAll, error: errMsg);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future<String> read() async {
    String text;

    if (filePath == PATH_STDIN) {
      text = readInputSync();
    }
    else {
      var file = new File(filePath);

      if (!(await file.exists())) {
        throw new Exception('Failed to find expected configuration file: "${filePath}"');
      }

      text = await file.readAsString();
    }

    return text;
  }

  static String readInputSync() {
    final List<int> input = [];

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
