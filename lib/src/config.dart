import 'package:doul/src/config_result.dart';
import 'package:doul/src/config_file_loader.dart';
import 'package:doul/src/ext/file_system_entity.dart';
import 'package:doul/src/ext/string.dart';
import 'package:doul/src/logger.dart';
import 'package:doul/src/options.dart';
import 'package:path/path.dart' as path_api;

////////////////////////////////////////////////////////////////////////////////

typedef ConfigFlatMapProc = ConfigResult Function(Map<String, String> map);

////////////////////////////////////////////////////////////////////////////////

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_RENAMES = '{{-rename-keywords-}}';
  static const String LIST_SEPARATOR = '\x01';
  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined parameters names
  //////////////////////////////////////////////////////////////////////////////

  String paramNameCanExpandContent = '{{-can-expand-content-}}';
  String paramNameCmd = '{{-cmd-}}';
  String paramNameCurDir = '{{-cur-dir-}}';
  String paramNameDetectPaths = '{{-detect-paths-}}';
  String paramNameDrop = '{{-drop-}}';
  String paramNameInp = '{{-inp-}}';
  String paramNameInpDir = '{{-inp-dir-}}';
  String paramNameInpExt = '{{-inp-ext-}}';
  String paramNameInpName = '{{-inp-name-}}';
  String paramNameInpNameExt = '{{-inp-name-ext-}}';
  String paramNameInpPath = '{{-inp-path-}}';
  String paramNameInpSubDir = '{{-inp-sub-dir-}}';
  String paramNameInpSubPath = '{{-inp-sub-path-}}';
  String paramNameImport = '{{-import-}}';
  String paramNameOut = '{{-out-}}';
  String paramNameNext = '{{-next-}}';
  String paramNameRun = '{{-run-}}';
  String paramNameStop = '{{-stop-}}';
  String paramNameThis = '{{-this-}}';

  List<String> paramNamesForGlob;
  List<String> paramNamesForPath;

  //////////////////////////////////////////////////////////////////////////////
  // Dependencies
  //////////////////////////////////////////////////////////////////////////////

  String paramNameResolvedIf; // to be calculated from condName*

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined commands
  //////////////////////////////////////////////////////////////////////////////

  String cmdNameExpand = '{{-expand-content-}}';

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined conditional operators
  //////////////////////////////////////////////////////////////////////////////

  String condNameIf = '{{-if-}}';
  String condNameThen = '{{-then-}}';
  String condNameElse = '{{-else-}}';

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined comparison operators
  //////////////////////////////////////////////////////////////////////////////

  String operNameEq = '==';
  String operNameEqi = '==/i';
  String operNameExists = '-e';
  String operNameNotExists = '!-e';
  String operNameGe = '>=';
  String operNameGt = '>';
  String operNameLe = '<=';
  String operNameLt = '<';
  String operNameNe = '!=';
  String operNameNei = '!=/i';
  String operNameNr = '!~';
  String operNameNri = '!~/i';
  String operNameRx = '~';
  String operNameRxi = '~/i';

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  Map all;
  RegExp detectPathsRE;
  Map<String, String> flatMap = {};
  List<Map<String, String>> flatMaps = [];
  int lastModifiedStamp = 0;
  Options options;
  String prevFlatMapStr;
  Map<List, Object> selections = {};
  Object topData;

  Logger _logger;

  //////////////////////////////////////////////////////////////////////////////

  Config(Logger log) {
    _logger = log;
    options = Options(_logger);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool canRun() {
    if (flatMap?.isEmpty ?? true) {
      return false;
    }

    if (!StringExt.isNullOrBlank(flatMap[paramNameRun])) {
      return true;
    }

    if (!StringExt.isNullOrBlank(flatMap[paramNameCmd])) {
      if (flatMap.containsKey(paramNameInp)) {
        if (flatMap.containsKey(paramNameOut)) {
          return true;
        }
      }
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult defaultExecFlatMap(Map<String, String> map) {
    if (_logger.isDebug) {
      _logger.debug('$map\n');
    }
    else {
      _logger.outInfo(map.containsKey(paramNameRun) ?
        'Run: ${expandStraight(map, map[paramNameRun] ?? '')}\n' :
        'Inp: ${expandStraight(map, map[paramNameInp] ?? '')}\n' +
        'Out: ${expandStraight(map, map[paramNameOut] ?? '')}\n' +
        'Cmd: ${expandStraight(map, map[paramNameCmd] ?? '')}\n'
      );
    }

    return ConfigResult.ok;
  }
  //////////////////////////////////////////////////////////////////////////////

  bool exec({List<String> args, ConfigFlatMapProc execFlatMap}) {
    options.parseArgs(args);

    if (options.isCmd) {
      return false;
    }

    _logger.information('Loading configuration data');

    var tmpAll = loadSync();

    if (tmpAll is Map) {
      all = tmpAll;
    }
    else {
      _logger.information('Nothing found');
      return null;
    }

    _logger.information('Processing configuration data');

    Map<String, Object> renames;

    if (all.containsKey(CFG_RENAMES)) {
      var map = all[CFG_RENAMES];

      if (map is Map<String, Object>) {
        renames = {};
        renames.addAll(map);
        all.remove(CFG_RENAMES);
      }
    }

    String actionKey;

    if (all.length == 1) {
      actionKey = all.keys.first;
    }

    var actions = (actionKey == null ? all : all[actionKey]);

    _logger.information('Processing renames');
    setActualParamNames(renames);

    if (actions != null) {
      _logger.information('Processing actions');

      topData = actions;
      selections.clear();
      execData(null, topData, execFlatMap);
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execData(String key, Object data, ConfigFlatMapProc execFlatMap) {
    var result = ConfigResult.ok;

    if (data == topData) {
      flatMap.clear();
      prevFlatMapStr = StringExt.EMPTY;
    }

    if (data is List) {
      var selection = selections[data];

      if (selection != null) {
        result = execData(key, selection, execFlatMap);
      }
      else {
        for (var childData in data) {
          selections[data] = childData;

          if (childData == null) {
            continue;
          }

          result = execData(null, topData, execFlatMap);

          if (result != ConfigResult.ok) {
            break;
          }
        }

        selections[data] = null;

        if (result == ConfigResult.ok) {
          result = ConfigResult.endOfList;
        }
      }
    }
    else if (data is Map<String, Object>) {
      if (key == condNameIf) {
        var resolvedData = resolveIf(data);

        if (resolvedData != null) {
          result = execData(paramNameResolvedIf, resolvedData, execFlatMap);
        }
      }
      else {
        data.forEach((childKey, childData) {
          if (result == ConfigResult.ok) {
            result = execData(childKey, childData, execFlatMap);
          }
        });

        if (result == ConfigResult.endOfList) {
          result = ConfigResult.ok;
        }
      }
    }
    else if (data == null) {
      flatMap.remove(key);
    }
    else if (key == paramNameDetectPaths) {
      var dataStr = data.toString().trim();
      detectPathsRE = (dataStr.isEmpty ? null : RegExp(dataStr));
    }
    else {
      if ((data is num) && ((data % 1) == 0)) {
        flatMap[key] = data.toStringAsFixed(0);
      }
      else {
        var dataStr = data.toString();

        if (dataStr.isNotEmpty) {
          var isKeyForGlob = paramNamesForGlob.contains(key);
          var isKeyForPath = paramNamesForPath.contains(key);
          var isDetectPaths = (detectPathsRE?.hasMatch(key) ?? false);
          var hasPath = (isKeyForGlob || isKeyForPath || isDetectPaths);

          if (hasPath) {
            dataStr = dataStr.adjustPath();
          }
        }

        flatMap[key] = dataStr;
      }

      if (canRun()) {
        if (isNewFlatMap()) {
          pushExeToBottom();
          execFlatMap(flatMap);
        }
        flatMap.remove(paramNameOut);
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandStraight(Map<String, String> map, String value) {
    if ((value == null) || (map == null)) {
      return value;
    }

    for (var oldValue = StringExt.EMPTY; oldValue != value;) {
      oldValue = value;

      map.forEach((k, v) {
        if (value.contains(k)) {
          value = value.replaceAll(k, v.toString());
        }
      });
    }

    return value;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getFullCurDirName(String curDirName) {
    return path_api.join(options.startDirName, curDirName).getFullPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> getInpParamNames() {
    return [
      paramNameInp,
      paramNameInpDir,
      paramNameInpExt,
      paramNameInpName,
      paramNameInpNameExt,
      paramNameInpPath,
      paramNameInpSubDir,
      paramNameInpSubPath,
    ];
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> getExeParamNames() {
    return [
      paramNameCmd,
      paramNameRun,
    ];
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isNewFlatMap() {
    var flatMapStr = sortAndEncodeFlatMap();
    var isNew = (flatMapStr != prevFlatMapStr);

    if (_logger.isDebug) {
      _logger.debug('Is new map: $isNew');
    }

    return isNew;
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object> loadSync() {
    var lf = ConfigFileLoader(log: _logger);
    lf.loadJsonSync(options.configFileInfo, paramNameImport: paramNameImport, appPlainArgs: options.plainArgs);

    lastModifiedStamp = lf.lastModifiedStamp;

    var data = lf.data;

    if (data is Map) {
      return data;
    }
    else {
      return <String, Object>{ '+': data };
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void pushExeToBottom() {
    var key = paramNameRun;
    var exe = flatMap[key];

    if (exe == null) {
      key = paramNameCmd;
      exe = flatMap[key];
    }

    if (exe != null) {
      flatMap.remove(key);
      flatMap[key] = exe;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Object resolveIf(Map<String, Object> mapIf) {
    var isOperFound = false;
    String operName;

    operName = (!isOperFound ? operNameExists : operName);
    var isExists = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isExists);

    operName = (!isOperFound ? operNameNotExists : operName);
    var isNotExists = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isNotExists);

    operName = (!isOperFound ? operNameEq : operName);
    var isEq = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isEq);

    operName = (!isOperFound ? operNameEqi : operName);
    var isEqi = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isEqi);

    operName = (!isOperFound ? operNameGe : operName);
    var isGe = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isGe);

    operName = (!isOperFound ? operNameGt : operName);
    var isGt = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isGt);

    operName = (!isOperFound ? operNameLe : operName);
    var isLe = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isLe);

    operName = (!isOperFound ? operNameLt : operName);
    var isLt = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isLt);

    operName = (!isOperFound ? operNameNe : operName);
    var isNe = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isNe);

    operName = (!isOperFound ? operNameNei : operName);
    var isNei = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isNei);

    operName = (!isOperFound ? operNameRx : operName);
    var isRx = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isRx);

    operName = (!isOperFound ? operNameRxi : operName);
    var isRxi = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isRxi);

    operName = (!isOperFound ? operNameNr : operName);
    var isNr = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isNe);

    operName = (!isOperFound ? operNameNri : operName);
    var isNri = (!isOperFound && mapIf.containsKey(operName));
    isOperFound = (isOperFound || isNri);

    if (!isOperFound) {
      throw Exception('Unknown conditional operation in "$condNameIf": "$mapIf"');
    }

    if (!mapIf.containsKey(condNameThen)) {
      throw Exception('Then-block not found in "$condNameIf": "$mapIf"');
    }

    var blockThen = mapIf[condNameThen];
    var blockElse = (mapIf.containsKey(condNameElse) ? mapIf[condNameElse] : null);

    if ((blockThen == null) && (blockElse == null)) {
      throw Exception('Incomplete IF operation: "$condNameIf": "$mapIf"');
    }

    var operValue = mapIf[operName];
    var operands = (operValue is List ? operValue : [ operValue as String ]);

    var isThen = true;

    if (isExists || isNotExists) {
      for (var entityName in operands) {
        if (entityName == null) {
          isThen = false;
          break;
        }

        var entityNameEx = expandStraight(flatMap, entityName);
        var isFound = FileSystemEntityExt.tryPatternExistsSync(entityNameEx);

        if ((isExists && !isFound) || (!isExists && isFound)) {
          isThen = false;
          break;
        }
      }
    }
    else {
      if (operands.length != 2) {
        throw Exception('Two operands precisely required for "$operName": $operands');
      }

      var isIgnoreCase  = (isEqi || isNei || isRxi || isNri);
      var isRegExpMatch = (isRx || isRxi || isNr || isNri);

      var o1 = expandStraight(flatMap, operands[0]?.toString());
      var o2 = expandStraight(flatMap, operands[1]?.toString());

      var n1 = (o1 == null ? null : (int.tryParse(o1) ?? double.tryParse(o1)));
      var n2 = (o2 == null ? null : (int.tryParse(o2) ?? double.tryParse(o2)));

      if ((n1 != null) && (n2 != null)) {
        if (isGe) {
          isThen = (n1 >= n2);
        }
        else if (isGt) {
          isThen = (n1 > n2);
        }
        else if (isLe) {
          isThen = (n1 <= n2);
        }
        else if (isLt) {
          isThen = (n1 < n2);
        }
        else if (isEq) {
          isThen = (n1 == n2);
        }
        else if (isNe) {
          isThen = (n1 == n2);
        }
        else {
          isThen = null;
        }
      }
      else {
        isThen = null;
      }

      if (isThen == null) {
        if (isIgnoreCase && !isRegExpMatch) {
          o1 = o1?.toUpperCase();
          o2 = o2?.toUpperCase();
        }

        if (isEq || isEqi) {
          isThen = (o1 == o2);
        }
        else if (isNe || isNei) {
          isThen = (o1 != o2);
        }
        else if (isGe) {
          isThen = ((o1?.compareTo(o2) ?? -1) >= 0);
        }
        else if (isGt) {
          isThen = ((o1?.compareTo(o2) ?? -1) > 0);
        }
        else if (isLe) {
          isThen = ((o1?.compareTo(o2) ?? 1) <= 0);
        }
        else if (isLt) {
          isThen = ((o1?.compareTo(o2) ?? 1) < 0);
        }
        else {
          var hasMatch = RegExp(o2, caseSensitive: !isIgnoreCase).hasMatch(o1);
          isThen = (isRx || isRxi ? hasMatch : (isNr || isNri ? !hasMatch : false));
        }
      }
    }

    return (isThen ? blockThen : blockElse);
  }

  //////////////////////////////////////////////////////////////////////////////

  void setActualParamNames(Map<String, Object> renames) {
    renames?.forEach((k, v) {
      if (k == paramNameCanExpandContent) {
        paramNameCanExpandContent = v;
      }
      else if (k == paramNameCmd) {
        paramNameCmd = v;
      }
      else if (k == paramNameCurDir) {
        paramNameCurDir = v;
      }
      else if (k == paramNameDetectPaths) {
        paramNameDetectPaths = v;
      }
      else if (k == paramNameDrop) {
        paramNameDrop = v;
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
      else if (k == paramNameNext) {
        paramNameNext = v;
      }
      else if (k == paramNameRun) {
        paramNameRun = v;
      }
      else if (k == paramNameStop) {
        paramNameStop = v;
      }
      else if (k == paramNameThis) {
        paramNameThis = v;
      }

      // Pre-defined conditions

      else if (k == condNameIf) {
        condNameIf = v;
      }
      else if (k == condNameThen) {
        condNameThen = v;
      }
      else if (k == condNameElse) {
        condNameElse = v;
      }

      // Pre-defined commands

      else if (k == cmdNameExpand) {
        cmdNameExpand = v;
      }
    });

    // Resolve dependencies - file names and paths

    paramNamesForGlob = [
      paramNameInp,
      paramNameInpDir,
      paramNameInpName,
      paramNameInpNameExt,
      paramNameInpPath,
      paramNameInpSubDir,
      paramNameInpSubPath,
    ];

    paramNamesForPath = [
      paramNameInp,
      paramNameInpDir,
      paramNameInpPath,
      paramNameInpSubDir,
      paramNameInpSubPath,
      paramNameOut,
      paramNameCurDir,
    ];

    // Resolve dependencies - If

    if ((condNameIf == null) || ((condNameThen == null) && (condNameElse == null))) {
      condNameThen = null;
      condNameElse = null;
      paramNameResolvedIf = null;
    }
    else {
      paramNameResolvedIf = condNameIf +
        (condNameThen ?? StringExt.EMPTY) +
        (condNameElse ?? StringExt.EMPTY);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String sortAndEncodeFlatMap() {
    var list = flatMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    var result = '{${list.map((x) =>
      '${x.key.quote()}:${x.value?.quote() ?? StringExt.EMPTY}'
    ).join(',')}';

    if (_logger.isDebug) {
      _logger.debug(result);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

}
