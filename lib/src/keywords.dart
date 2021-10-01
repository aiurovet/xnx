
class Keywords {
  String forCanExpandContent = '{{-can-expand-content-}}';
  String forCmd = '{{-cmd-}}';
  String forCurDir = '{{-cur-dir-}}';
  String forDetectPaths = '{{-detect-paths-}}';
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
  String forRename = '{{-rename-keywords-}}';
  String forStop = '{{-stop-}}';
  String forThis = '{{-this-}}';
  String forTransform = '{{-xform-}}';

  String forFnAdd = '=Add';
  String forFnAddDays = '=AddDays';
  String forFnAddMonths = '=AddMonths';
  String forFnAddYears = '=AddYears';
  String forFnDate = '=Date';
  String forFnDiv = '=Div';
  String forFnEndOfMonth = '=EndOfMonth';
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

  final allForGlob = <String>[];
  final allForPath = <String>[];

  //////////////////////////////////////////////////////////////////////////////
  // Dependencies
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined commands
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Pre-defined conditional operators
  //////////////////////////////////////////////////////////////////////////////

  String? forIf = '{{-if-}}';
  String? forThen = '{{-then-}}';
  String? forElse = '{{-else-}}';

  //////////////////////////////////////////////////////////////////////////////

  List<String> getAllForInp() {
    return [
      forInp,
      forInpDir,
      forInpExt,
      forInpName,
      forInpNameExt,
      forInpPath,
      forInpSubDir,
      forInpSubPath,
    ];
  }

  //////////////////////////////////////////////////////////////////////////////

  List<String> getAllForExe() {
    return [
      forCmd,
      forRun,
    ];
  }

  //////////////////////////////////////////////////////////////////////////////

  void rename(Map<String, Object?>? renames) {
    renames?.forEach((k, v) {
      var s = (v?.toString() ?? '');

      if (k == forCanExpandContent) {
        forCanExpandContent = s;
      }
      else if (k == forCmd) {
        forCmd = s;
      }
      else if (k == forCurDir) {
        forCurDir = s;
      }
      else if (k == forDetectPaths) {
        forDetectPaths = s;
      }
      else if (k == forInp) {
        forInp = s;
      }
      else if (k == forInpDir) {
        forInpDir = s;
      }
      else if (k == forInpExt) {
        forInpExt = s;
      }
      else if (k == forInpName) {
        forInpName = s;
      }
      else if (k == forInpNameExt) {
        forInpNameExt = s;
      }
      else if (k == forInpPath) {
        forInpPath = s;
      }
      else if (k == forInpSubDir) {
        forInpSubDir = s;
      }
      else if (k == forInpSubPath) {
        forInpSubPath = s;
      }
      else if (k == forImport) {
        forImport = s;
      }
      else if (k == forOnce) {
        forOnce = s;
      }
      else if (k == forOut) {
        forOut = s;
      }
      else if (k == forRun) {
        forRun = s;
      }
      else if (k == forRename) {
        forRename = s;
      }
      else if (k == forStop) {
        forStop = s;
      }
      else if (k == forThis) {
        forThis = s;
      }
      else if (k == forTransform) {
        forTransform = s;
      }

      // Pre-defined conditions

      else if (k == forIf) {
        forIf = s;
      }
      else if (k == forThen) {
        forThen = s;
      }
      else if (k == forElse) {
        forElse = s;
      }

      // Pre-defined commands

      // else if (k == cmdNameExpand) {
      //   cmdNameExpand = s;
      // }
    });

    // Resolve dependencies - file names and paths

    allForGlob..clear()..addAll([
      forInp,
      forInpDir,
      forInpName,
      forInpNameExt,
      forInpPath,
      forInpSubDir,
      forInpSubPath,
    ]);

    allForPath..clear()..addAll([
      forInp,
      forInpDir,
      forInpPath,
      forInpSubDir,
      forInpSubPath,
      forOut,
      forCurDir,
    ]);

    // Resolve dependencies - If

    if ((forIf == null) || ((forThen == null) && (forElse == null))) {
      forIf = null;
      forThen = null;
      forElse = null;
    }
  }
}