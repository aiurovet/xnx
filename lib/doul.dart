import 'dart:io';

import 'convert.dart';
import 'ext/string.dart';
import 'log.dart';

class Doul {
  static void main(List<String> args) {
    var isOK = false;

    Convert.exec(args)
      .then((result) {
        isOK = true;
      })
      .catchError((e, stackTrace) {
        var cleanMsg = RegExp(r'^Exception[\:\s]*', caseSensitive: false);
        var errMsg = e?.toString()?.replaceFirst(cleanMsg, StringExt.EMPTY);

        if (StringExt.isNullOrBlank(errMsg)) {
          isOK = true; // help
        }
        else {
          var errDtl = (Log.isDetailed() ? '\n\n' + stackTrace?.toString() : StringExt.EMPTY);
          errMsg = '\n*** ERROR: ${errMsg}${errDtl}\n';

          Log.error(errMsg);
        }
      })
      .whenComplete(() {
        exit(isOK ? 0 : 1);
      });
  }
}