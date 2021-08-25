import 'package:xnx/src/config_key_data.dart';
import 'package:xnx/src/config_result.dart';
import 'package:xnx/src/config_file_loader.dart';
import 'package:xnx/src/expression.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';
import 'package:path/path.dart' as path_api;

////////////////////////////////////////////////////////////////////////////////

typedef ConfigFlatMapProc = ConfigResult Function(Map<String, String> map);

////////////////////////////////////////////////////////////////////////////////

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String LIST_SEPARATOR = '\x01';
  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined parameters names
  //////////////////////////////////////////////////////////////////////////////

  String paramNameCanExpandContent = '{{-can-expand-content-}}';
  String paramNameCmd = '{{-cmd-}}';
  String paramNameCurDir = '{{-cur-dir-}}';
  String paramNameDetectPaths = '{{-detect-paths-}}';
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
  String paramNameRun = '{{-run-}}';
  String paramNameRename = '{{-rename-keywords-}}';
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

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined conditional operators
  //////////////////////////////////////////////////////////////////////////////

  String condNameIf = '{{-if-}}';
  String condNameThen = '{{-then-}}';
  String condNameElse = '{{-else-}}';

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  Map all;
  RegExp detectPathsRE;
  Expression expression;
  Map<String, String> flatMap = {};
  List<Map<String, String>> flatMaps = [];
  int lastModifiedStamp = 0;
  Options options;
  String prevFlatMapStr;
  Object topData;

  final Map<Object, ConfigKeyData> _trail = {};
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

    if (all.containsKey(paramNameRename)) {
      var map = all[paramNameRename];

      if (map is Map<String, Object>) {
        renames = {};
        renames.addAll(map);
        all.remove(paramNameRename);
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
      execData(null, topData, execFlatMap);
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execData(String key, Object data, ConfigFlatMapProc execFlatMap) {
    if (data == null) {
      flatMap.remove(key);
      return (key == paramNameStop ? ConfigResult.stop : ConfigResult.ok);
    }

    var trailKeyData = _trail[data];

    if (trailKeyData != null) {
      return execData(trailKeyData.key, trailKeyData.data, execFlatMap);
    }

    if (data is List) {
      if (key == paramNameRun) { // direct execution in a loop
        return execDataListRun(key, data, execFlatMap);
      }
      else {
        return execDataList(key, data, execFlatMap);
      }
    }

    if (data is Map<String, Object>) {
      if (key == condNameIf) {
        return execDataMapIf(key, data, execFlatMap);
      }
      else {
        return execDataMap(key, data, execFlatMap);
      }
    }

    return execDataPlain(key, data, execFlatMap);
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataList(String key, List data, ConfigFlatMapProc execFlatMap) {
    for (var childData in data) {
      if (childData == null) {
        continue;
      }

      setTrailFor(data, key, childData);
      var result = execData(null, topData, execFlatMap);

      if ((result != ConfigResult.ok) && (result != ConfigResult.okEndOfList)) {
        return result;
      }
    }

    setTrailFor(data, null, null);
    flatMap.remove(key);

    return ConfigResult.okEndOfList;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataListRun(String key, List data, ConfigFlatMapProc execFlatMap) {
    var result = ConfigResult.ok;

    for (var childData in data) {
      if (childData == null) {
        continue;
      }

      flatMap[key] = childData.toString().trim();
      result = execDataRun(execFlatMap);

      if (result != ConfigResult.ok) {
        break;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataMap(String key, Map<String, Object> data, ConfigFlatMapProc execFlatMap) {
    var result = ConfigResult.ok;

    data.forEach((childKey, childData) {
      if (result == ConfigResult.ok) {
        result = execData(childKey, childData, execFlatMap);
      }
    });

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataMapIf(String key, Map<String, Object> data, ConfigFlatMapProc execFlatMap) {
    var result = ConfigResult.ok;

    var resolvedData = expression.exec(data);

    if (resolvedData != null) {
      setTrailFor(data, condNameThen, resolvedData);
      result = execData(condNameThen, resolvedData, execFlatMap);
      setTrailFor(data, null, null);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataPlain(String key, Object data, ConfigFlatMapProc execFlatMap) {
    var result = ConfigResult.ok;

    if ((data is num) && ((data % 1) == 0)) {
      flatMap[key] = data.toStringAsFixed(0);
      return result;
    }

    var dataStr = data.toString().trim();
    var isEmpty = dataStr.isEmpty;

    if (key == paramNameDetectPaths) {
      detectPathsRE = (isEmpty ? null : RegExp(dataStr));
      return result;
    }

    if (key == paramNameStop) {
      if (!isEmpty) {
        _logger.out(expandStraight(flatMap, dataStr));
      }

      return ConfigResult.stop;
    }

    if (!isEmpty) {
      var isKeyForGlob = paramNamesForGlob.contains(key);
      var isKeyForPath = paramNamesForPath.contains(key);
      var isDetectPaths = (detectPathsRE?.hasMatch(key) ?? false);
      var hasPath = (isKeyForGlob || isKeyForPath || isDetectPaths);

      if (hasPath) {
        dataStr = dataStr.adjustPath();
      }
    }

    var isCmd = (key == paramNameCmd);
    var isRun = (key == paramNameRun);

    if (isCmd || isRun) {
      flatMap.remove(isCmd ? paramNameRun : paramNameCmd);
    }

    flatMap[key] = dataStr;

    if (canRun()) {
      result = execDataRun(execFlatMap);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataRun(ConfigFlatMapProc execFlatMap) {
    var result = ConfigResult.ok;

    if (isNewFlatMap()) {
      pushExeToBottom();
      result = execFlatMap(flatMap);

      flatMap.removeWhere((k, v) =>
        (k == paramNameOut) || (k == paramNameRun)
      );
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
    prevFlatMapStr = flatMapStr;

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

  void print(String msg, {bool isSilent}) {
    if (!(isSilent ?? false)) {
      _logger.out(msg ?? StringExt.EMPTY);
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
      else if (k == paramNameRun) {
        paramNameRun = v;
      }
      else if (k == paramNameRename) {
        paramNameRename = v;
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

      // else if (k == cmdNameExpand) {
      //   cmdNameExpand = v;
      // }
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

    expression = Expression(this);
  }

  //////////////////////////////////////////////////////////////////////////////

  void setTrailFor(Object currData, String toKey, Object toData) {
    if (toKey == null) {
      _trail.remove(currData);
    }
    else {
      _trail[currData] = ConfigKeyData(toKey, toData);
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
