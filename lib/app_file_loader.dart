import 'dart:convert';
import 'dart:io';

import 'package:doul/options.dart';

import 'ext/stdin.dart';
import 'ext/string.dart';
import 'log.dart';

class AppFileLoader {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String ALL_ARGS = r'${@}';
  static final RegExp RE_CMD_LINE_ARG = RegExp(r'(\$\*|\$\@|\$\{\*\}|\${\@\})|(\$([1-9][0-9]*))|(\$\{([1-9][0-9]*)\})');

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

  AppFileLoader({bool isStdIn, File file, String text}) {
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

  void expandCmdLineArgs() {
    var args = Options.plainArgs;
    var argCount = (args?.length ?? 0);

    _text = _text
      .replaceAll('\$\$', '\x01')
      .replaceAllMapped(RE_CMD_LINE_ARG, (match) {
        if (match.group(1) != null) {
          return ALL_ARGS; // will be expanded later
        }

        var envArgNo = (match.group(3) ?? match.group(5));

        if (envArgNo != null) {
          var argNo = (int.tryParse(envArgNo) ?? -1);

          if ((argNo > 0) && (argNo <= argCount)) {
            return args[argNo - 1];
          }
        }

        return StringExt.EMPTY;
      })
      .replaceAll('\x01', '\$');
  }

  //////////////////////////////////////////////////////////////////////////////

  AppFileLoader loadImportsSync(String paramNameImport) {
    if (StringExt.isNullOrBlank(paramNameImport)) {
      return this;
    }

    var pattern = r'\"' + RegExp.escape(paramNameImport) + r'\"\s*\:\s*(\"(.*?)\")';
    var regExp = RegExp(pattern);

    if (!regExp.hasMatch(_text)) {
      return this;
    }

    var lf = AppFileLoader();

    _text = _text
      .replaceAll(r'\\', '\x01')
      .replaceAll('\'', '\x02')
      .replaceAll(r'\"', '\x03')
      .replaceAllMapped(regExp, (match) {
        var inpPath = match.group(2);
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

  AppFileLoader loadJsonSync(String path, {String paramNameImport}) {
    loadSync(path);

    _text = _text.removeJsComments();

    if (!StringExt.isNullOrBlank(paramNameImport)) {
      loadImportsSync(paramNameImport);
    }

    expandCmdLineArgs();
    _text = _text.expandEnvironmentVariables();
    _data = jsonDecode(_text);
    _text = null;

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  AppFileLoader loadSync(String path) {
    _isStdIn = (StringExt.isNullOrBlank(path) || (path == StringExt.STDIN_PATH));
    var dispName = (_isStdIn ? path : '"' + path + '"');

    Log.information('Loading ${dispName}');

    _file = (_isStdIn ? null : File(path));

    if (_file == null) {
      _text = stdin.readAsStringSync();
    }
    else {
      if (!_file.existsSync()) {
        throw Exception('File not found: ${dispName}');
      }

      _text = (_file.readAsStringSync() ?? StringExt.EMPTY);
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////
}