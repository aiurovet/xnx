
import 'package:glob/glob.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';

class PathFilter {

  //////////////////////////////////////////////////////////////////////////////

  bool isNot = false;
  bool isPath = false;

  Glob? mask;
  RegExp? regex;

  String? maskPattern;
  String? regexPattern;

  //////////////////////////////////////////////////////////////////////////////

  bool get isEmpty => ((maskPattern == null) && (regexPattern == null));

  //////////////////////////////////////////////////////////////////////////////

  PathFilter({bool? isNot, bool? isPath, String? mask, String? regex}) {
    init(isNot: isNot, isPath: isPath, mask: mask, regex: regex);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool hasMatch(String path) {
    var nameOrPath = (isPath ? path : Path.basename(path));

    var hasMatch = (mask?.matches(nameOrPath) ?? true) &&
                   (regex?.hasMatch(nameOrPath) ?? true);
   
    return (isNot ? !hasMatch : hasMatch);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool finalize({String? maskPattern, String? regexPattern}) {
    maskPattern ??= this.maskPattern;
    regexPattern ??= this.regexPattern;

    mask = (maskPattern?.isBlank() ?? true ? null : Glob(maskPattern ?? ''));
    regex = (regexPattern?.isBlank() ?? true ? null : RegExp(regexPattern ?? '', caseSensitive: !Path.isWindowsFS));

    return ((mask != null) || (regex != null));
  }

  //////////////////////////////////////////////////////////////////////////////

  void init({bool? isNot, bool? isPath, String? mask, String? regex}) {
    if (isNot != null) {
      this.isNot = isNot;
    }
    if (isPath != null) {
      this.isPath = isPath;
    }
    if (mask != null) {
      mask = mask.trim();
      maskPattern = (mask.isEmpty ? null : mask);
    }
    if (regex != null) {
      regex = regex.trim();
      regexPattern = (regex.isEmpty ? null : regex);
    }

    this.mask = null;
    this.regex = null;
  }

  //////////////////////////////////////////////////////////////////////////////
}