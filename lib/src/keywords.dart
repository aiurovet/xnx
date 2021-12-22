import 'package:meta/meta.dart';

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
  String forFilesIsNot = 'isNot';
  String forFilesIsPath = 'isPath';
  String forFilesMask = 'mask';
  String forFilesRegex = 'regex';
  String forFilesSkip = '{{-skip-}}';
  String forFilesTake = '{{-take-}}';
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
  String forNumericPrecision = 'numericPrecision';
  String forOnce = '{{-once-}}';
  String forOut = '{{-out-}}';
  String forRun = '{{-run-}}';
  String forStop = '{{-stop-}}';
  String forThis = '{{-this-}}';

  String forFnAdd = '=Add';
  String forFnAddDays = '=AddDays';
  String forFnAddMonths = '=AddMonths';
  String forFnAddYears = '=AddYears';
  String forFnBaseName = '=BaseName';
  String forFnBaseNameNoExt = '=BaseNameNoExt';
  String forFnCeil = '=Ceil';
  String forFnCos = '=Cos';
  String forFnDate = '=Date';
  String forFnDirName = '=DirName';
  String forFnDiv = '=Div';
  String forFnDivInt = '=IDiv';
  String forFnEndOfMonth = '=EndOfMonth';
  String forFnExp = '=Exp';
  String forFnExtension = '=Extension';
  String forFnFileSize = '=FileSize';
  String forFnFloor = '=Floor';
  String forFnIndex = '=Index';
  String forFnMatch = '=Match';
  String forFnLastIndex = '=LastIndex';
  String forFnLastMatch = '=LastMatch';
  String forFnLastModified = '=LastModified';
  String forFnLen = '=Len';
  String forFnLn = '=Ln';
  String forFnLocal = '=Local';
  String forFnLower = '=Lower';
  String forFnMax = '=Max';
  String forFnMin = '=Min';
  String forFnMod = '=Mod';
  String forFnMul = '=Mul';
  String forFnNow = '=Now';
  String forFnPi = '=Pi';
  String forFnPow = '=Pow';
  String forFnRad = '=Rad';
  String forFnReplace = '=Replace';
  String forFnReplaceMatch = '=ReplaceMatch';
  String forFnRound = '=Round';
  String forFnRun = '=Run';
  String forFnStartOfMonth = '=StartOfMonth';
  String forFnSin = '=Sin';
  String forFnSqrt = '=Sqrt';
  String forFnSub = '=Sub';
  String forFnSubstr = '=Substr';
  String forFnTan = '=Tan';
  String forFnTime = '=Time';
  String forFnTitle = '=Title';
  String forFnToday = '=Today';
  String forFnUpper = '=Upper';
  String forFnUtc = '=Utc';

  //////////////////////////////////////////////////////////////////////////////
  // Derived
  //////////////////////////////////////////////////////////////////////////////

  RegExp rexRepeatable = RegExp('');

  final all = <String>[];
  final allForExe = <String>[];
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

  void init(Map data) {
    var rawNode = data['keywords'];

    if (rawNode != null) {
      var node = (rawNode as Map);

      forIf = node['kwIf'] ?? forIf;
      forElse = node['kwElse'] ?? forElse;

      forCanExpandContent = node['kwCanExpandContent'] ?? forCanExpandContent;
      forCmd = node['kwCmd'] ?? forCmd;
      forCurDir = node['kwCurDir'] ?? forCurDir;
      forDetectPaths = node['kwDetectPaths'] ?? forDetectPaths;
      forFilesIsNot = node['kwFilesIsNot'] ?? forFilesIsNot;
      forFilesIsPath = node['kwFilesIsPath'] ?? forFilesIsPath;
      forFilesMask = node['kwFilesMask'] ?? forFilesMask;
      forFilesRegex = node['kwFilesRegex'] ?? forFilesRegex;
      forFilesSkip = node['kwFilesSkip'] ?? forFilesSkip;
      forFilesTake = node['kwFilesTake'] ?? forFilesTake;
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
      forNumericPrecision = node['kwNumericPrecision'] ?? forNumericPrecision;
      forOnce = node['kwOnce'] ?? forOnce;
      forOut = node['kwOut'] ?? forOut;
      forRun = node['kwRun'] ?? forRun;
      forStop = node['kwStop'] ?? forStop;
      forThis = node['kwThis'] ?? forThis;
    }

    _initRepeatable();

    rawNode = data['functions'];

    if (rawNode != null) {
      var node = (data['functions'] as Map);

      forFnAdd = node['fnAdd'] ?? forFnAdd;
      forFnAddDays = node['fnAddDays'] ?? forFnAddDays;
      forFnAddMonths = node['fnAddMonths'] ?? forFnAddMonths;
      forFnAddYears = node['fnAddYears'] ?? forFnAddYears;
      forFnBaseName = node['fnBaseName'] ?? forFnBaseName;
      forFnBaseNameNoExt = node['fnBaseNameNoExt'] ?? forFnBaseNameNoExt;
      forFnCos = node['fnCos'] ?? forFnCos;
      forFnExp = node['fnExp'] ?? forFnExp;
      forFnDate = node['fnDate'] ?? forFnDate;
      forFnDirName = node['fnDirName'] ?? forFnDirName;
      forFnDiv = node['fnDiv'] ?? forFnDiv;
      forFnDivInt = node['fnDivInt'] ?? forFnDivInt;
      forFnEndOfMonth = node['fnEndOfMonth'] ?? forFnEndOfMonth;
      forFnExtension = node['fnExtension'] ?? forFnExtension;
      forFnFileSize = node['fnFileSize'] ?? forFnFileSize;
      forFnIndex = node['fnIndex'] ?? forFnIndex;
      forFnLastIndex = node['fnLastIndex'] ?? forFnLastIndex;
      forFnLastMatch = node['fnLastMatch'] ?? forFnLastMatch;
      forFnLastModified = node['fnLastModified'] ?? forFnLastModified;
      forFnLen = node['fnLen'] ?? forFnLen;
      forFnLn = node['fnLn'] ?? forFnLn;
      forFnLocal = node['fnLocal'] ?? forFnLocal;
      forFnLower = node['fnLower'] ?? forFnLower;
      forFnMatch = node['fnMatch'] ?? forFnMatch;
      forFnMax = node['fnMax'] ?? forFnMax;
      forFnMin = node['fnMin'] ?? forFnMin;
      forFnMod = node['fnMod'] ?? forFnMod;
      forFnMul = node['fnMul'] ?? forFnMul;
      forFnNow = node['fnNow'] ?? forFnNow;
      forFnPi = node['fnPi'] ?? forFnPi;
      forFnPow = node['fnPow'] ?? forFnPow;
      forFnRad = node['fnRad'] ?? forFnRad;
      forFnReplace = node['fnReplace'] ?? forFnReplace;
      forFnReplaceMatch = node['fnReplaceMatch'] ?? forFnReplaceMatch;
      forFnRun = node['fnRun'] ?? forFnRun;
      forFnStartOfMonth = node['fnStartOfMonth'] ?? forFnStartOfMonth;
      forFnSin = node['fnSin'] ?? forFnSin;
      forFnSqrt = node['fnSqrt'] ?? forFnSqrt;
      forFnSub = node['fnSub'] ?? forFnSub;
      forFnSubstr = node['fnSubstr'] ?? forFnSubstr;
      forFnTan = node['fnTan'] ?? forFnTan;
      forFnTime = node['fnTime'] ?? forFnTime;
      forFnTitle = node['fnTitle'] ?? forFnTitle;
      forFnToday = node['fnToday'] ?? forFnToday;
      forFnUpper = node['fnUpper'] ?? forFnUpper;
      forFnUtc = node['fnUtc'] ?? forFnUtc;
    }

    _initDerived();
  }

  //////////////////////////////////////////////////////////////////////////////

  String? refine(String? key, {String? prefixForOthers}) {
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

    if (key.startsWith(forStop)) { return forStop; }
    if (key.startsWith(forFilesSkip)) { return forFilesSkip; }
    if (key.startsWith(forFilesTake)) { return forFilesTake; }

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

    return (prefixForOthers == null ? key : prefixForOthers + key);
  }

  //////////////////////////////////////////////////////////////////////////////
  // Internal methods
  //////////////////////////////////////////////////////////////////////////////

  void _initDerived() {
    all..clear()..addAll([
      forCanExpandContent, forCmd, forCurDir, forDetectPaths,
      forFunc, forInp, forInpDir, forInpExt, forInpName,
      forInpNameExt, forInpPath,  forInpSubDir, forInpSubPath,
      forImport, forOnce, forOut, forRun, forFilesSkip, forStop,
      forFilesTake, forThis,
    ]);

    allForExe..clear()..addAll([
      forCmd, forRun,
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