import 'package:doul/config_event.dart';
import 'package:doul/config_feed.dart';
import 'package:doul/config_file_loader.dart';
import 'package:doul/ext/directory.dart';
import 'package:doul/ext/file_system_entity.dart';
import 'package:doul/ext/glob.dart';
import 'package:doul/ext/string.dart';
import 'package:doul/logger.dart';
import 'package:doul/options.dart';
import 'package:path/path.dart' as pathx;

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

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
  String cmdNameSub = '{{-sub-}}';

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
  var lastModifiedStamp = 0;
  Options options;

  Map<String, String> growMap;

  Logger _logger;

  //////////////////////////////////////////////////////////////////////////////

  Config(Logger log) {
    _logger = log;
    options = Options(_logger);
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigEventResult defaultMapExec(Map<String, String> flatMap) {
    growMap = flatMap;

    if (_logger.isUltimate) {
      _logger.debug(flatMap.toString() + '\n');
    }
    else {
      _logger.outInfo(expandStraight(flatMap, (
        flatMap[paramNameOut] ?? flatMap[paramNameCmd] ??
        flatMap[paramNameRun] ?? flatMap[paramNameInp] ??
        StringExt.EMPTY
      )));
    }

    return ConfigEventResult.ok;
  }
  //////////////////////////////////////////////////////////////////////////////

  bool exec({List<String> args, ConfigMapExec mapExec}) {
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

    var action = (all.containsKey(CFG_ACTION) ? all[CFG_ACTION] : all);
    var rename = (action == all ? null : (all.containsKey(CFG_RENAME) ? all[CFG_RENAME] : null));

    _logger.information('Processing renames');
    setActualParamNames(rename);

    if (action != null) {
      _logger.information('Processing actions');

      growMap = {};
      execFeed(action, mapExec);
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  void execFeed(Object actions, [ConfigMapExec mapExec]) {
    var hasCmd = false;
    var hasInp = false;
    var hasOut = false;
    var isReady = false;

    var feed = ConfigFeed(
      dataParsed: (ConfigData data) {
        var key = data.key;

        if (key == paramNameDrop) {
          return ConfigEventResult.drop;
        }

        if (key == paramNameNext) {
          return ConfigEventResult.next;
        }

        var value = data.data;
        var strValue = value?.toString()?.trim();
        var isBlank = StringExt.isNullOrBlank(strValue);
        var isNull = (value == null);

        if (key == paramNameDetectPaths) {
          detectPathsRE = (isBlank ? null : RegExp(strValue));
          return ConfigEventResult.ok;
        }

        if (key == condNameIf) {
          if (!isBlank) {
            data.data = resolveIfDeep(value, true);
            data.key = paramNameResolvedIf;
          }

          return ConfigEventResult.ok;
        }

        if (data.type != ConfigDataType.plain) {
          return ConfigEventResult.ok;
        }

        if (isNull) {
          growMap.remove(key);
        }
        else {
          growMap[key] = strValue;
        }

        var canHaveWildcards = !isBlank && (
          paramNamesForGlob.contains(key) ||
          (detectPathsRE?.hasMatch(key) ?? false)
        );

        if (canHaveWildcards) {
          if (GlobExt.isGlobPattern(strValue)) {
            try {
              data.data = DirectoryExt.pathListExSync(strValue);
              return ConfigEventResult.ok;
            }
            catch (e) {
              // suppress
            }
          }
        }

        if (key == paramNameCmd) {
          hasCmd = !isNull;
        }
        else if (key == paramNameInp) {
          hasInp = !isNull;
        }
        else if (key == paramNameOut) {
          hasOut = !isNull;
        }
        else if (key == paramNameRun) {
          isReady = true;

          if (isBlank) {
            data.data = null;
          }
        }

        if (isReady || (hasCmd && hasInp && hasOut)) {
          isReady = false;
          hasOut = false;
          return ConfigEventResult.run;
        }

        return ConfigEventResult.ok;
      },

      mapExec: mapExec ?? defaultMapExec
    );

    feed.exec(actions);
    growMap.clear();
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
    return pathx.join(options.startDirName, curDirName).getFullPath();
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

        var entityNameEx = expandStraight(growMap, entityName);
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

      var o1 = expandStraight(growMap, operands[0]?.toString());
      var o2 = expandStraight(growMap, operands[1]?.toString());

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

  Object resolveIfDeep(Object data, bool isMapIf) {
    if (isMapIf ?? false) {
      data = resolveIfDeep(resolveIf(data), false);
    }
    else if (data is List) {
      for (var i = 0, n = data.length; i < n; i++) {
        data[i] = resolveIfDeep(data[i], false);
      }
    }
    else if (data is Map) {
      var map = (data as Map);

      if (map.length == 1) {
        var mapIf = map[condNameIf];

        if (mapIf != null) {
          return resolveIfDeep(resolveIf(mapIf), false);
        }
      }

      var newData = <String, Object>{};

      map.forEach((childKey, childValue) {
        var childKeyStr = childKey.toString();

        if (childKeyStr == condNameIf) {
          newData[paramNameResolvedIf] = resolveIfDeep(resolveIf(childValue), false);
        }
        else if ((childValue is List) || (childValue is Map)) {
          newData[childKeyStr] = resolveIfDeep(childValue, false);
        }
        else {
          newData[childKeyStr] = childValue;
        }
      });

      map.clear();
      data = newData;
    }

    return data;
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
      else if (k == paramNameRun) {
        paramNameRun = v;
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
      else if (k == paramNameDrop) {
        paramNameDrop = v;
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
      else if (k == cmdNameSub) {
        cmdNameSub = v;
      }
    });

    // Resolve dependencies - paths

    paramNamesForGlob = [
      paramNameInp,
      paramNameInpDir,
      paramNameInpName,
      paramNameInpNameExt,
      paramNameInpPath,
      paramNameInpSubDir,
      paramNameInpSubPath,
    ];

    paramNamesForPath = [];
    paramNamesForPath.addAll(paramNamesForGlob);
    paramNamesForPath.add(paramNameOut);

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

}
