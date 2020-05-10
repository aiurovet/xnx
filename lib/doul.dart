import 'dart:io';

import 'convert.dart';
import 'ext/string.dart';
import 'log.dart';

class Doul {
  static void main(List<String> args) {
    var isOK = false;

    try {
      Convert().exec(args);
      isOK = true;
    }
    catch (e, stackTrace) {
      isOK = onError(e, stackTrace);
    }

    exit(isOK ? 0 : 1);
  }

  static bool onError(Exception e, StackTrace stackTrace) {
    var errDecorRE = RegExp(r'^Exception[\:\s]*', caseSensitive: false);
    var errMsg = e?.toString()?.replaceFirst(errDecorRE, StringExt.EMPTY);
    var isOK = false;

    if (StringExt.isNullOrBlank(errMsg)) {
      isOK = true; // help
    }
    else {
      var errDtl = (Log.isDetailed() ? '\n\n' + stackTrace?.toString() : StringExt.EMPTY);
      errMsg = '\n*** ERROR: ${errMsg}${errDtl}\n';

      Log.error(errMsg);
    }

    return isOK;
  }
}