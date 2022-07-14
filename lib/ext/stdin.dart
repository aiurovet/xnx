import 'dart:convert';
import 'dart:io';

import 'package:xnx/ext/string.dart';

extension StdinExt on Stdin {

  //////////////////////////////////////////////////////////////////////////////

  String readAsStringSync({int endByte = StringExt.eotCode}) {
    final input = <int>[];

    for (var isEmpty = true; ; isEmpty = false) {
      var byte = stdin.readByteSync();

      if ((byte < 0) || ((endByte != 0) && (byte == endByte))) {
        if (isEmpty) {
          return '';
        }

        break;
      }

      input.add(byte);
    }

    return utf8.decode(input, allowMalformed: true);
  }

  //////////////////////////////////////////////////////////////////////////////

}