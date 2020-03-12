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
    .catchError((e) {
      var errMsg = e.message;

      if (StringExt.isNullOrBlank(errMsg)) {
        isOK = true; // help
      }
      else {
        Log.error('\n${errMsg}\n');
      }
    })
    .whenComplete(() {
      exit(isOK ? 0 : 1);
    });
}
