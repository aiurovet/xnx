import 'dart:io';

import 'ext/stdin.dart';
import 'ext/string.dart';
import 'log.dart';

class LoadedFile {

  //////////////////////////////////////////////////////////////////////////////

  final bool isStdIn;
  final String data;
  final File file;

  //////////////////////////////////////////////////////////////////////////////

  LoadedFile({this.isStdIn, this.file, this.data});

  //////////////////////////////////////////////////////////////////////////////

  static LoadedFile loadSync(String path) {
    var isStdIn = (path == StringExt.STDIN_PATH);
    var dispName = (isStdIn ? path : '"' + path + '"');

    Log.information('Loading ${dispName}');

    var file = (isStdIn ? null : File(path));
    String text;

    if (file == null) {
      text = stdin.readAsStringSync(endByte: StringExt.EOT_CODE);
    }
    else {
      if (!file.existsSync()) {
        throw Exception('File not found: ${dispName}');
      }

      text = file.readAsStringSync();
    }

    return LoadedFile(isStdIn: isStdIn, file: file, data: text);
  }

  //////////////////////////////////////////////////////////////////////////////
}