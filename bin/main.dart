import 'dart:io';

import 'package:doul/convert.dart';
import 'package:doul/ext/string.dart';

void main(List<String> args) {
  var isOK = false;

  Convert.exec(args)
    .then((result) {
      isOK = true;
    })
    .catchError((e) {
      var errMsg = e.message;

      if (!StringExt.isNullOrBlank(errMsg)) {
        print('\n*** ERROR: ${errMsg}\n');
      }
    })
    .whenComplete(() {
      exit(isOK ? 0 : 1);
    });
}
