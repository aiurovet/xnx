import 'dart:convert';
import 'dart:io';

extension StdinExt on Stdin {
  String readAsStringSync({int endByte}) {
    endByte ??= 0;

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

    return utf8.decode(input, allowMalformed: true);
  }
}