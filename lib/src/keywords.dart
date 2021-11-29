
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
  String forRename = '{{-rename-keywords-}}';
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

  String forIf = '{{-if-}}';
  String forThen = '{{-then-}}';
  String forElse = '{{-else-}}';

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
    if (key.startsWith(forRename)) { return forRename; }
    if (key.startsWith(forThis)) { return forThis; }

    return key;
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
      else if (k == forFunc) {
        forFunc = s;
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
  }
}