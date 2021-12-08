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
  String forDetectPaths = '{{-detectPaths-}}';
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

  RegExp rexRepeatable = RegExp('');

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

    _initRepeatable();
  }

  //////////////////////////////////////////////////////////////////////////////

  void load(Options options) {
    logger.information('Loading the application configuration');

    if (options.appConfigPath.isNotEmpty) {
      var file = Path.fileSystem.file(options.appConfigPath);
      var text = file.readAsStringSync();
      var data = json5Decode(text);

      var node = data['keywords'];

      forIf = node['kwIf'] ?? forIf;
      forIf = node['kwThen'] ?? forThen;
      forIf = node['kwElse'] ?? forElse;

      forCanExpandContent = node['kwCanExpandContent'] ?? forCanExpandContent;
      forCmd = node['kwCmd'] ?? forCmd;
      forCurDir = node['kwCurDir'] ?? forCurDir;
      forDetectPaths = node['kwDetectPaths'] ?? forDetectPaths;
      forFunc = node['kwFunc'] ?? forFunc;
      forInp = node['kwInp'] ?? forInp;
      forInpDir = node['kwInpDir'] ?? forInpDir;
      forInpExt = node['kwInpExt'] ?? forInpExt;
      forInpName = node['kwInpName'] ?? forInpName;
      forInpNameExt = node['kwInpNameExt'] ?? forInpNameExt;
      forInpPath = node['kwInpPath'] ?? forInpPath;
      forInpSubDir = node['kwInpSubDir'] ?? forInpSubDir;
      forInpSubPath = node['kwInpSubPath'] ?? forInpSubPath;
      forImport = node['kwImport'] ?? forImport;
      forOnce = node['kwOnce'] ?? forOnce;
      forOut = node['kwOut'] ?? forOut;
      forRun = node['kwRun'] ?? forRun;
      forSkip = node['kwSkip'] ?? forSkip;
      forStop = node['kwStop'] ?? forStop;
      forTake = node['kwTake'] ?? forTake;
      forThis = node['kwThis'] ?? forThis;

      _initRepeatable();

      node = data['functions'];

      forFnAdd = node['fnAdd'] ?? forFnAdd;
      forFnAddDays = node['fnAddDays'] ?? forFnAddDays;
      forFnAddMonths = node['fnAddMonths'] ?? forFnAddMonths;
      forFnAddYears = node['fnAddYears'] ?? forFnAddYears;
      forFnBaseName = node['fnBaseName'] ?? forFnBaseName;
      forFnBaseNameNoExt = node['fnBaseNameNoExt'] ?? forFnBaseNameNoExt;
      forFnDate = node['fnDate'] ?? forFnDate;
      forFnDirName = node['fnDirName'] ?? forFnDirName;
      forFnDiv = node['fnDiv'] ?? forFnDiv;
      forFnDivInt = node['fnIDiv'] ?? forFnDivInt;
      forFnEndOfMonth = node['fnEndOfMonth'] ?? forFnEndOfMonth;
      forFnExtension = node['fnExtension'] ?? forFnExtension;
      forFnFileSize = node['fnFileSize'] ?? forFnFileSize;
      forFnIndex = node['fnIndex'] ?? forFnIndex;
      forFnMatch = node['fnMatch'] ?? forFnLastIndex;
      forFnLastIndex = node['fnLastIndex'] ?? forFnLastIndex;
      forFnLastMatch = node['fnLastMatch'] ?? forFnMatch;
      forFnLastModified = node['fnLastModified'] ?? forFnLastModified;
      forFnLocal = node['fnLocal'] ?? forFnLocal;
      forFnLower = node['fnLower'] ?? forFnLower;
      forFnMax = node['fnMax'] ?? forFnMax;
      forFnMin = node['fnMin'] ?? forFnMin;
      forFnMod = node['fnMod'] ?? forFnMod;
      forFnMul = node['fnMul'] ?? forFnMul;
      forFnNow = node['fnNow'] ?? forFnNow;
      forFnReplace = node['fnReplace'] ?? forFnReplace;
      forFnReplaceMatch = node['fnReplaceMatch'] ?? forFnReplaceMatch;
      forFnRun = node['fnRun'] ?? forFnRun;
      forFnStartOfMonth = node['fnStartOfMonth'] ?? forFnStartOfMonth;
      forFnSub = node['fnSub'] ?? forFnSub;
      forFnSubstr = node['fnSubstr'] ?? forFnSubstr;
      forFnTime = node['fnTime'] ?? forFnTime;
      forFnToday = node['fnToday'] ?? forFnToday;
      forFnUpper = node['fnUpper'] ?? forFnUpper;
      forFnUtc = node['fnUtc'] ?? forFnUtc;
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

  //////////////////////////////////////////////////////////////////////////////

  void _initRepeatable() =>
    rexRepeatable = RegExp('(${RegExp.escape(forCanExpandContent)}|${RegExp.escape(forCmd)}|${RegExp.escape(forDetectPaths)}|${RegExp.escape(forFunc)}|${RegExp.escape(forIf)}|${RegExp.escape(forImport)}|${RegExp.escape(forOnce)}|${RegExp.escape(forRun)}|${RegExp.escape(forStop)}|${RegExp.escape(forThis)})(\\s*[\'"]\\:)', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

}