import 'dart:convert';
import 'dart:io';

import 'package:doul/ext/string.dart';

extension StdinExt on Stdin {

  //////////////////////////////////////////////////////////////////////////////

  String readAsStringSync({int endByte}) {
    endByte ??= StringExt.EOT_CODE;

    final input = <int>[];

    for (var isEmpty = true; ; isEmpty = false) {
      var byte = stdin.readByteSync();

      if ((byte < 0) || ((endByte != 0) && (byte == endByte))) {
        if (isEmpty) {
          return null;
        }

        break;
      }

      input.add(byte);
    }

    return (utf8.decode(input, allowMalformed: true) ?? StringExt.EMPTY);
  }

  //////////////////////////////////////////////////////////////////////////////

}