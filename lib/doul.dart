import 'dart:io';

import 'convert.dart';
import 'ext/string.dart';
import 'log.dart';
import 'options.dart';

class Doul {
  static void main(List<String> args) {
    var isOK = false;

    try {
      exec(args);
      isOK = true;
    }
    on ArgumentError catch (e, stackTrace) {
      isOK = onError(e?.toString(), stackTrace);
    }
    on Exception catch (e, stackTrace) {
      isOK = onError(e?.toString(), stackTrace);
    }

    exit(isOK ? 0 : 1);
  }

  static void exec(List<String> args) {
    Convert().exec(args);
  }

  static bool onError(String errMsg, StackTrace stackTrace) {
    if (StringExt.isNullOrBlank(errMsg)) {
      return false;
    }
    else {
      var errDecorRE = RegExp(r'^Exception[\:\s]*', caseSensitive: false);
      errMsg = errMsg.replaceFirst(errDecorRE, StringExt.EMPTY);

      if (errMsg == Options.HELP['name']) {
        return true;
      }
      else if (Log.isSilent) {
        return false;
      }

      var errDtl = (Log.isDetailed ? '\n\n' + stackTrace?.toString() : StringExt.EMPTY);
      errMsg = '\n*** ERROR: ${errMsg}${errDtl}\n';

      Log.error(errMsg);

      return false;
    }
  }
}