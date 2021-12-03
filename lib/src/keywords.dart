import 'package:json5/json5.dart';
import 'package:meta/meta.dart';

import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';

class Keywords {

  //////////////////////////////////////////////////////////////////////////////
  // All of these keys are searched using 'statsWith' rather than 'equals', as
  // they are allowed not to be unique per map
  //////////////////////////////////////////////////////////////////////////////

  String forCanExpandContent = '{{-can-expand-content-}}';
  String forCmd = '{{-cmd-}}';
  String forCurDir = '{{-cur-dir-}}';
  String forDetectPaths = '{{-detect-paths-}}';
  String forFunc = '{{-func-}}';
  String forInp = '{{-inp-}}';
  String forInpDir = '{{-inp-dir-}}';
  String forInpExt = '{{-inp-ext-}}';
  String forInpName = '{{-inp-name-}}';
  String forInpNameExt = '{{-inp-name-ext-}}';
  String forInpPath = '{{-inp-path-}}';
  String forInpSubDir = '{{-inp-sub-dir-}}';
  String forInpSubPath = '{{-inp-sub-path-}}';
  String forImport = '{{-import-}}';
  String forOnce = '{{-once-}}';
  String forOut = '{{-out-}}';
  String forRun = '{{-run-}}';
  String forSkip = '{{-skip-}}';
  String forStop = '{{-stop-}}';
  String forTake = '{{-take-}}';
  String forThis = '{{-this-}}';

  String forFnAdd = '=Add';
  String forFnAddDays = '=AddDays';
  String forFnAddMonths = '=AddMonths';
  String forFnAddYears = '=AddYears';
  String forFnBaseName = '=BaseName';
  String forFnBaseNameNoExt = '=BaseNameNoExt';
  String forFnDate = '=Date';
  String forFnDirName = '=DirName';
  String forFnDiv = '=Div';
  String forFnDivInt = '=IDiv';
  String forFnEndOfMonth = '=EndOfMonth';
  String forFnExtension = '=Extension';
  String forFnFileSize = '=FileSize';
  String forFnIndex = '=Index';
  String forFnMatch = '=Match';
  String forFnLastIndex = '=LastIndex';
  String forFnLastMatch = '=LastMatch';
  String forFnLastModified = '=LastModified';
  String forFnLocal = '=Local';
  String forFnLower = '=Lower';
  String forFnMax = '=Max';
  String forFnMin = '=Min';
  String forFnMod = '=Mod';
  String forFnMul = '=Mul';
  String forFnNow = '=Now';
  String forFnReplace = '=Replace';
  String forFnReplaceMatch = '=ReplaceMatch';
  String forFnRun = '=Run';
  String forFnStartOfMonth = '=StartOfMonth';
  String forFnSub = '=Sub';
  String forFnSubstr = '=Substr';
  String forFnTime = '=Time';
  String forFnToday = '=Today';
  String forFnUpper = '=Upper';
  String forFnUtc = '=Utc';

  //////////////////////////////////////////////////////////////////////////////
  // Derived
  //////////////////////////////////////////////////////////////////////////////

  final allForExe = <String>[];
  final allForExpand = <String>[];
  final allForGlob = <String>[];
  final allForInp = <String>[];
  final allForPath = <String>[];

  //////////////////////////////////////////////////////////////////////////////
  // Dependencies
  //////////////////////////////////////////////////////////////////////////////

  @protected late final Logger logger;
  @protected late final Options options;

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined commands
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined conditional operators
  //////////////////////////////////////////////////////////////////////////////

  String forIf = '{{-if-}}';
  String forThen = '{{-then-}}';
  String forElse = '{{-else-}}';

  //////////////////////////////////////////////////////////////////////////////

  Keywords({Options? options, Logger? logger}) {
    if (logger != null) {
      this.logger = logger;
    }
    if (options != null) {
      this.options = options;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////

  void load(Options options) {
    logger.information('Loading the application configuration');

    if (options.appConfigPath.isNotEmpty) {
      var file = Path.fileSystem.file(options.appConfigPath);
      var text = file.readAsStringSync();
      var data = json5Decode(text);

      var node = data['keywords'];

      forIf = node['if'] ?? forIf;
      forIf = node['then'] ?? forThen;
      forIf = node['else'] ?? forElse;

      forCanExpandContent = node['canExpandContent'] ?? forCanExpandContent;
      forCmd = node['cmd'] ?? forCmd;
      forCurDir = node['curDir'] ?? forCurDir;
      forDetectPaths = node['detectPaths'] ?? forDetectPaths;
      forFunc = node['func'] ?? forFunc;
      forInp = node['inp'] ?? forInp;
      forInpDir = node['inpDir'] ?? forInpDir;
      forInpExt = node['inpExt'] ?? forInpExt;
      forInpName = node['inpName'] ?? forInpName;
      forInpNameExt = node['inpNameExt'] ?? forInpNameExt;
      forInpPath = node['inpPath'] ?? forInpPath;
      forInpSubDir = node['inpSubDir'] ?? forInpSubDir;
      forInpSubPath = node['inpSubPath'] ?? forInpSubPath;
      forImport = node['import'] ?? forImport;
      forOnce = node['once'] ?? forOnce;
      forOut = node['out'] ?? forOut;
      forRun = node['run'] ?? forRun;
      forSkip = node['skip'] ?? forSkip;
      forStop = node['stop'] ?? forStop;
      forTake = node['take'] ?? forTake;
      forThis = node['this'] ?? forThis;

      node = data['functions'];

      forFnAdd = node['=Add'] ?? forFnAdd;
      forFnAddDays = node['=AddDays'] ?? forFnAddDays;
      forFnAddMonths = node['=AddMonths'] ?? forFnAddMonths;
      forFnAddYears = node['=AddYears'] ?? forFnAddYears;
      forFnBaseName = node['=BaseName'] ?? forFnBaseName;
      forFnBaseNameNoExt = node['=BaseNameNoExt'] ?? forFnBaseNameNoExt;
      forFnDate = node['=Date'] ?? forFnDate;
      forFnDirName = node['=DirName'] ?? forFnDirName;
      forFnDiv = node['=Div'] ?? forFnDiv;
      forFnDivInt = node['=IDiv'] ?? forFnDivInt;
      forFnEndOfMonth = node['=EndOfMonth'] ?? forFnEndOfMonth;
      forFnExtension = node['=Extension'] ?? forFnExtension;
      forFnFileSize = node['=FileSize'] ?? forFnFileSize;
      forFnIndex = node['=Index'] ?? forFnIndex;
      forFnMatch = node['=Match'] ?? forFnLastIndex;
      forFnLastIndex = node['=LastIndex'] ?? forFnLastIndex;
      forFnLastMatch = node['=LastMatch'] ?? forFnMatch;
      forFnLastModified = node['=LastModified'] ?? forFnLastModified;
      forFnLocal = node['=Local'] ?? forFnLocal;
      forFnLower = node['=Lower'] ?? forFnLower;
      forFnMax = node['=Max'] ?? forFnMax;
      forFnMin = node['=Min'] ?? forFnMin;
      forFnMod = node['=Mod'] ?? forFnMod;
      forFnMul = node['=Mul'] ?? forFnMul;
      forFnNow = node['=Now'] ?? forFnNow;
      forFnReplace = node['=Replace'] ?? forFnReplace;
      forFnReplaceMatch = node['=ReplaceMatch'] ?? forFnReplaceMatch;
      forFnRun = node['=Run'] ?? forFnRun;
      forFnStartOfMonth = node['=StartOfMonth'] ?? forFnStartOfMonth;
      forFnSub = node['=Sub'] ?? forFnSub;
      forFnSubstr = node['=Substr'] ?? forFnSubstr;
      forFnTime = node['=Time'] ?? forFnTime;
      forFnToday = node['=Today'] ?? forFnToday;
      forFnUpper = node['=Upper'] ?? forFnUpper;
      forFnUtc = node['=Utc'] ?? forFnUtc;
    }

    _initDerived();
  }

  //////////////////////////////////////////////////////////////////////////////

  String? refine(String? key) {
    if (key == null) { return key; }

    // Frequency level 1
    
    if (key.startsWith(forOnce)) { return forOnce; }
    if (key.startsWith(forFunc)) { return forFunc; }
    if (key.startsWith(forCmd)) { return forCmd; }

    // Frequency level 2

    if (key.startsWith(forIf)) { return forIf; }
    if (key.startsWith(forCurDir)) { return forCurDir; }
    if (key.startsWith(forRun)) { return forRun; }
    if (key.startsWith(forDetectPaths)) { return forDetectPaths; }

    // Frequency level 3

    if (key.startsWith(forSkip)) { return forSkip; }
    if (key.startsWith(forStop)) { return forStop; }
    if (key.startsWith(forTake)) { return forTake; }

    // Frequency level 4

    if (key.startsWith(forInp)) { return forInp; }
    if (key.startsWith(forInpDir)) { return forInpDir; }
    if (key.startsWith(forInpExt)) { return forInpExt; }
    if (key.startsWith(forInpName)) { return forInpName; }
    if (key.startsWith(forInpNameExt)) { return forInpNameExt; }
    if (key.startsWith(forInpPath)) { return forInpPath; }
    if (key.startsWith(forInpSubDir)) { return forInpSubDir; }
    if (key.startsWith(forInpSubPath)) { return forInpSubPath; }
    if (key.startsWith(forOut)) { return forOut; }

    // Frequency level 5

    if (key.startsWith(forCanExpandContent)) { return forCanExpandContent; }
    if (key.startsWith(forImport)) { return forImport; }
    if (key.startsWith(forThis)) { return forThis; }

    return key;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Internal methods
  //////////////////////////////////////////////////////////////////////////////

  void _initDerived() {
    allForExe..clear()..addAll([
      forCmd, forRun,
    ]);

    allForExpand..clear()..addAll([
      forCanExpandContent, forCmd, forCurDir, forDetectPaths,
      forInp, forInpDir, forInpExt, forInpName, forInpNameExt,
      forInpPath,  forInpSubDir, forInpSubPath,forOut, forRun,
      forThis,
    ]);

    allForGlob..clear()..addAll([
      forInp, forInpDir, forInpName, forInpNameExt, forInpPath,
      forInpSubDir, forInpSubPath,
    ]);

    allForInp..clear()..addAll([
      forInp, forInpDir, forInpExt, forInpName, forInpNameExt,
      forInpPath, forInpSubDir, forInpSubPath,
    ]);

    allForPath..clear()..addAll([
      forInp, forInpDir, forInpPath, forInpSubDir, forInpSubPath,
      forOut, forCurDir,
    ]);
  }
}