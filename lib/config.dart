import 'package:path/path.dart' as Path;
import 'app_file_loader.dart';
import 'log.dart';
import 'options.dart';
import 'ext/string.dart';

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

  static final String CMD_REPLACE = 'replace-only';

  //static final int MAX_EXPANSION_ITERATIONS = 10;

  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedMcsec;

  String paramNameCanReplaceContent = '{{-can-replace-content-}}';
  String paramNameCmd = '{{-cmd-}}';
  String paramNameCurDir = '{{-cur-dir-}}';
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

  //////////////////////////////////////////////////////////////////////////////
  // Native conditional operators
  //////////////////////////////////////////////////////////////////////////////

  String condNameIf = '{{-if-}}';
  String condNameThen = '{{-then-}}';
  String condNameElse = '{{-else-}}';

  //////////////////////////////////////////////////////////////////////////////
  // Native comparison operators
  //////////////////////////////////////////////////////////////////////////////

  String operNameEq = '==';
  String operNameEqi = '==/i';
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
  // Native commands: general-purpose - NOT IMPLEMENTED YET
  //////////////////////////////////////////////////////////////////////////////

  String cmdNameCopy = '{{-cmd-copy-}}';
  String cmdNameCopyNewer = '{{-cmd-copy-newer-}}';
  String cmdNameDelete = '{{-cmd-delete-}}';
  String cmdNameMove = '{{-cmd-move-}}';
  String cmdNameMoveNewer = '{{-cmd-move-newer-}}';
  String cmdNameRemove = '{{-cmd-remove-}}'; // same as delete
  String cmdNameRename = '{{-cmd-rename-}}'; // same as move
  String cmdNameRenameNewer = '{{-cmd-rename-newer-}}'; // same as move

  //////////////////////////////////////////////////////////////////////////////
  // Native commands: archiving - NOT IMPLEMENTED YET
  //////////////////////////////////////////////////////////////////////////////

  String cmdNameBz2 = '{{-cmd-bz2-}}';
  String cmdNameUnBz2 = '{{-cmd-unbz2-}}';
  String cmdNameGz = '{{-cmd-gz-}}';
  String cmdNameUnGz = '{{-cmd-ungz-}}';
  String cmdNamePack = '{{-cmd-pack-}}'; // based on input file extension
  String cmdNameUnPack = '{{-cmd-unpack-}}'; // based on input file extension
  String cmdNameTar = '{{-cmd-tar-}}';
  String cmdNameUnTar = '{{-cmd-untar-}}';
  String cmdNameTarGz = '{{-cmd-tar-gz-}}';
  String cmdNameUnTarGz = '{{-cmd-untar-gz-}}';
  String cmdNameZip = '{{-cmd-zip-}}';
  String cmdNameUnZip = '{{-cmd-unzip-}}';

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
        if (k == condNameIf) {
          v = resolveMapForIf(v);
        }

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

      var actions = (action as List);
      var result = <Map<String, String>>[];

      actions.forEach((map) {
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

  bool isParamWithPath(String paramName) {
    return (
        (paramName == paramNameCurDir) ||
        (paramName == paramNameInp) ||
        (paramName == paramNameOut)
    );
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
      paramNameInpSubPath
    ];
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object> loadConfigSync() {
    var lf = AppFileLoader().loadJsonSync(Options.configFilePath, paramNameImport: paramNameImport);

    lastModifiedMcsec = lf.lastModifiedMcsec;

    if (lf.data is Map) {
      return (lf.data as Map).values.toList()[0];
    }
    else {
      return lf.data;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object> resolveMapForIf(Map<String, Object> mapIf) {
    var result = <String, Object>{};

    var isOperFound = false;
    var operName = operNameEq;
    var isEq = (!isOperFound && mapIf.containsKey(operName));

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
    isOperFound = (isOperFound || isNei);

    if (!isOperFound) {
      throw Exception('Unknown conditional operation in "${condNameIf}": "${mapIf}"');
    }

    if (!mapIf.containsKey(condNameThen)) {
      throw Exception('Then-block not found in "${condNameIf}": "${mapIf}"');
    }

    var blockThen = mapIf[condNameThen];
    var blockElse = (mapIf.containsKey(condNameElse) ? mapIf[condNameElse] : null);

    var isIgnoreCase = (isEqi || isNei || isRxi || isNri);
    var isRegExpMatch = (isRx || isRxi || isNr || isNri);
    var isStringOper = (isIgnoreCase || isRegExpMatch);

    var operands = (mapIf[operName] as List);

    if (operands.length != 2) {
      throw Exception('Two operands precisely required for "${operName}": ${operands}');
    }

    var o1 = operands[0];
    var o2 = operands[1];

    if (isStringOper) {
      o1 = o1.toString();
      o2 = o2.toString();

      if (isIgnoreCase && !isRegExpMatch) {
        o1 = o1.toUpperCase();
        o2 = o2.toUpperCase();
      }
    }
    else {
      var isNum1 = ((o1 is int) || (o1 is double));
      var isNum2 = ((o2 is int) || (o2 is double));

      if (isNum1 && !isNum2) {
        o2 = o2.toString();
        o2 = (int.tryParse(o2) ?? double.tryParse(o2));
      }
      else if (!isNum1 && isNum2) {
        o1 = o1.toString();
        o1 = (int.tryParse(o1) ?? double.tryParse(o1));
      }
      else if (!isNum1 && !isNum2) {
        o1 = o1.toString();
        o1 = (int.tryParse(o1) ?? double.tryParse(o1));
        o2 = o2.toString();
        o2 = (int.tryParse(o2) ?? double.tryParse(o2));
      }

      if ((o1 == null) || (o2 == null)) {
        if (isGe || isGt || isLe || isLt) {
          throw Exception('Two numbers expected in "${operName}": ${operands}');
        }

        o1 = operands[0].toString();
        o2 = operands[1].toString();
      }
    }

    if (isEq || isEqi) {
      result = (o1 == o2 ? blockThen : blockElse);
    }
    else if (isNe || isNei) {
      result = (o1 != o2 ? blockThen : blockElse);
    }
    else if (isGe) {
      result = (o1 >= o2 ? blockThen : blockElse);
    }
    else if (isGt) {
      result = (o1 > o2 ? blockThen : blockElse);
    }
    else if (isLe) {
      result = (o1 <= o2 ? blockThen : blockElse);
    }
    else if (isLt) {
      result = (o1 < o2 ? blockThen : blockElse);
    }
    else {
      var hasMatch = RegExp(o2, caseSensitive: !isIgnoreCase).hasMatch(o1);

      if (isRx || isRxi) {
        result = (hasMatch ? blockThen : blockElse);
      }
      else if (isNr || isNri) {
        result = (!hasMatch ? blockThen : blockElse);
      }
    }

    if (result == null) {
      throw Exception('Incomplete IF operation: "${condNameIf}": "${mapIf}"');
    }

    return result;
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
      else if (k == paramNameCanReplaceContent) {
        paramNameCanReplaceContent = v;
      }

      // Native commands: general-purpose - NOT IOMPLEMENTED YET

      if (k == cmdNameCopy) {
        cmdNameCopy = v;
      }
      else if (k == cmdNameDelete) {
        cmdNameDelete = v;
      }
      else if (k == cmdNameMove) {
        cmdNameMove = v;
      }
      else if (k == cmdNameRemove) {
        cmdNameRemove = v;
      }
      else if (k == cmdNameRename) {
        cmdNameRename = v;
      }

      // Native commands: archiving - NOT IOMPLEMENTED YET

      else if (k == cmdNameBz2) {
        cmdNameBz2 = v;
      }
      else if (k == cmdNameUnBz2) {
        cmdNameUnBz2 = v;
      }
      else if (k == cmdNameGz) {
        cmdNameGz = v;
      }
      else if (k == cmdNameUnGz) {
        cmdNameUnGz= v;
      }
      else if (k == cmdNamePack) {
        cmdNamePack = v;
      }
      else if (k == cmdNameUnPack) {
        cmdNameUnPack = v;
      }
      else if (k == cmdNameTar) {
        cmdNameTar = v;
      }
      else if (k == cmdNameUnTar) {
        cmdNameUnTar= v;
      }
      else if (k == cmdNameTarGz) {
        cmdNameTarGz = v;
      }
      else if (k == cmdNameUnTarGz) {
        cmdNameUnTarGz= v;
      }
      else if (k == cmdNameZip) {
        cmdNameZip = v;
      }
      else if (k == cmdNameUnZip) {
        cmdNameUnZip = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
