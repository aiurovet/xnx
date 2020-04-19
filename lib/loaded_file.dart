import 'dart:convert';
import 'dart:io';

import 'ext/stdin.dart';
import 'ext/string.dart';
import 'log.dart';

class LoadedFile {

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  Object _data;
  Object get data => _data;

  File _file;
  File get file => _file;

  bool _isStdIn;
  bool get isStdIn => _isStdIn;

  int _lastModifiedMcsec;
  int get lastModifiedMcsec => _lastModifiedMcsec;

  String _text;
  String get text => _text;

  //////////////////////////////////////////////////////////////////////////////
  // Construction
  //////////////////////////////////////////////////////////////////////////////

  LoadedFile({bool isStdIn, File file, String text}) {
    _file = file;
    _isStdIn = (isStdIn ?? false);
    _lastModifiedMcsec = (file?.lastModifiedSync()?.microsecondsSinceEpoch ?? 0);
    _text = text;
  }

  //////////////////////////////////////////////////////////////////////////////

  void clear() {
    _data = null;
    _file = null;
    _isStdIn = null;
    _lastModifiedMcsec = null;
    _text = null;
  }

  //////////////////////////////////////////////////////////////////////////////

  LoadedFile loadImportsSync(String paramNameImport) {
    if (StringExt.isNullOrBlank(paramNameImport)) {
      return this;
    }

    var pattern = '[\\"\\\']' + paramNameImport + '[\\"\\\']\\s*\\:\\s*(\\"([^\\"]+)\\")|(\\\'([^\\\']+)\\\')';
    var regExp = RegExp(pattern);

    if (!regExp.hasMatch(_text)) {
      return this;
    }

    var lf = LoadedFile();

    _text = _text
      .replaceAll(r'\\', '\x01')
      .replaceAll('\'', '\x02')
      .replaceAll(r'\"', '\x03')
      .replaceAllMapped(regExp, (match) {
        var inpPath = (match.group(2) ?? match.group(4));
        lf.loadSync(inpPath);

        var result = '"${paramNameImport}": ${lf.text}';
        lf.clear();

        return result;
      })
      .replaceAll('\x03', r'\"')
      .replaceAll('\x02', '\'')
      .replaceAll('\x01', r'\\')
    ;

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Methods
  //////////////////////////////////////////////////////////////////////////////

  LoadedFile loadJsonSync(String path, {String paramNameImport}) {
    loadSync(path);

    _text = _text.removeJsComments();

    if (!StringExt.isNullOrBlank(paramNameImport)) {
      loadImportsSync(paramNameImport);
    }

    _data = jsonDecode(_text);
    _text = null;

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  LoadedFile loadSync(String path) {
    _isStdIn = (StringExt.isNullOrBlank(path) || (path == StringExt.STDIN_PATH));
    var dispName = (_isStdIn ? path : '"' + path + '"');

    Log.information('Loading ${dispName}');

    _file = (_isStdIn ? null : File(path));

    if (_file == null) {
      _text = stdin.readAsStringSync(endByte: StringExt.EOT_CODE);
    }
    else {
      if (!_file.existsSync()) {
        throw Exception('File not found: ${dispName}');
      }

      _text = _file.readAsStringSync();
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////
}