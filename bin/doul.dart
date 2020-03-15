import 'dart:io';

import 'package:doul/convert.dart';
import 'package:doul/ext/string.dart';
import 'package:doul/log.dart';

void main(List<String> args) {
  var isOK = false;

  Convert.exec(args)
    .then((result) {
      isOK = true;
    })
    .catchError((e, stackTrace) {
      var errMsg = e?.toString();

      if (StringExt.isNullOrBlank(errMsg)) {
        isOK = true; // help
      }
      else {
        if (Log.isDetailed()) {
          errMsg += '\n\n';
          errMsg += stackTrace;
        }

        Log.error('\n${errMsg}\n');
      }
    })
    .whenComplete(() {
      exit(isOK ? 0 : 1);
    });
}
