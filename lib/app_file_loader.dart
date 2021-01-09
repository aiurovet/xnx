import 'dart:convert';
import 'dart:io';

import 'ext/file.dart';
import 'ext/stdin.dart';
import 'ext/string.dart';
import 'log.dart';

class AppFileLoader {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String IMP_FILE_KEY_SEP = '_';

  static final String ALL_ARGS = r'${@}';
  static final RegExp RE_CMD_LINE_ARG = RegExp(r'(\$\*|\$\@|\$\{\*\}|\${\@\})|(\$([0-9]+))|(\$\{([1-9][0-9]*)\})');
  static final RegExp RE_IMP_FILE_KEY_BAD_CHARS = RegExp(r'[\\\/\.,;]');
  static final RegExp RE_JSON_MAP_BRACES = RegExp(r'^[\s\{]+|[\s\}]+$');

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  Object _data;
  Object get data => _data;

  File _file;
  File get file => _file;

  bool _isStdIn;
  bool get isStdIn => _isStdIn;

  int _lastModifiedStamp;
  int get lastModifiedStamp => _lastModifiedStamp;

  String _text;
  String get text => _text;

  //////////////////////////////////////////////////////////////////////////////
  // Construction
  //////////////////////////////////////////////////////////////////////////////

  AppFileLoader({bool isStdIn, File file, String text}) {
    _file = file;
    _isStdIn = (isStdIn ?? false);
    _lastModifiedStamp = (file?.lastModifiedStampSync() ?? 0);
    _text = text;
  }

  //////////////////////////////////////////////////////////////////////////////

  void clear() {
    _data = null;
    _file = null;
    _isStdIn = null;
    _lastModifiedStamp = null;
    _text = null;
  }

  //////////////////////////////////////////////////////////////////////////////

  void expandCmdLineArgs(List<String> args) {
    var argCount = (args?.length ?? 0);
    var startCmd = FileExt.getStartCommand(escapeQuotes: true);

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
          else if (argNo == 0) {
            return startCmd;
          }
        }

        return StringExt.EMPTY;
      })
      .replaceAll('\x01', '\$');
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getImportFileKey(String prefix, {String impPath}) {
    var key = StringExt.EMPTY;

    if (!StringExt.isNullOrBlank(prefix)) {
      key += prefix;
    }

    if (!StringExt.isNullOrBlank(impPath)) {
      key += IMP_FILE_KEY_SEP;
      key += impPath.replaceAll(RE_IMP_FILE_KEY_BAD_CHARS, IMP_FILE_KEY_SEP);
    }

    return key;
  }

  //////////////////////////////////////////////////////////////////////////////

  String importFiles(String paramNameImport, {String impPath, impPathsSerialized}) {
    try {
      var fullText = StringExt.EMPTY;
      var keyPrefix = 'import';

      if (!StringExt.isNullOrBlank(impPath)) {
        loadSync(impPath);
        fullText = text;
      }
      else {
        fullText += '{';

        var jsonData = jsonDecode('{"${paramNameImport}": ${impPathsSerialized}}');
        var jsonText = StringExt.EMPTY;
        var impPaths = jsonData[paramNameImport];

        for (impPath in impPaths) {
          loadSync(impPath);

          if (fullText.length > 1) {
            fullText += ',';
          }

          jsonData = jsonDecode(text);
          var map = <String, Object>{};
          map[getImportFileKey(keyPrefix, impPath: impPath)] = jsonData.values.toList()[0];

          jsonText = jsonEncode(map).replaceAll(RE_JSON_MAP_BRACES, StringExt.EMPTY);
          fullText += jsonText;
        }

        fullText += '}';
      }

      clear();

      var result = '"${getImportFileKey(keyPrefix, impPath: impPath)}": ${fullText}';

      return result;
    }
    catch (e) {
      throw Exception('Failed to parse file: "${impPath}"\n\n${e.toString()}');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  AppFileLoader loadImportsSync(String paramNameImport) {
    if (StringExt.isNullOrBlank(paramNameImport)) {
      return this;
    }

    var pattern = r'([\{\[\,])\s*\"' + RegExp.escape(paramNameImport) + r'\"\s*\:\s*((\"(.*?)\")|(\[[^\]]+\]))\s*([,\]\}])';
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
        var impPath = match.group(4);
        var impPathsSerialized = match.group(5);

        var openChar = match.group(1);
        var closeChar = match.group(6);
        var result = openChar + lf.importFiles(paramNameImport, impPath: impPath, impPathsSerialized: impPathsSerialized) + closeChar;

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

  AppFileLoader loadJsonSync(String path, {String paramNameImport, List<String> appPlainArgs}) {
    loadSync(path);

    if (!StringExt.isNullOrBlank(paramNameImport)) {
      loadImportsSync(paramNameImport);
    }

    expandCmdLineArgs(appPlainArgs);
    _text = _text.expandEnvironmentVariables();
    _data = jsonDecode(_text);
    _text = null;

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  AppFileLoader loadSync(String pathAndFilter) {
    var parts = pathAndFilter.split(',');
    var path = parts[0];
    var filter = (parts.length > 1 ? parts[1] : null);

    _isStdIn = (StringExt.isNullOrBlank(path) || (path == StringExt.STDIN_PATH));
    var displayName = (_isStdIn ? path : '"' + path + '"');

    Log.information('Loading ${displayName}');

    _file = (_isStdIn ? null : File(path));

    if (_file == null) {
      _text = stdin.readAsStringSync();
    }
    else {
      if (!_file.existsSync()) {
        throw Exception('File not found: ${displayName}');
      }

      _text = (_file.readAsStringSync() ?? StringExt.EMPTY);
    }

    _text = _text.removeJsComments();

    if (!StringExt.isNullOrBlank(filter)) {
      var jsonData = jsonDecode(_text);

      var steps = filter.split('/');

      var map = jsonData as Map;
      var stepCount = steps.length;

      dynamic val;

      for (var stepNo = 0; (stepNo < stepCount) && (map != null); stepNo++) {
        var step = steps[stepNo];
        val = map[step];

        if (val is List) {
          ++stepNo;

          if (stepNo == stepCount) {
            val = null;
          }
          else {
            step = steps[stepNo];

            val = val.firstWhere(
              (m) => ((m is Map) && m.containsKey(step)),
              orElse: () => null
            );

            if ((val == null) || !(val is Map)) {
              break;
            }

            val = val[step];

            if (val is Map) {
              map = val;
            }
          }
        }
        else if (val is Map) {
          map = val;
        }
        else {
          val = null;
          break;
        }
      }

      _text = (val == null ? StringExt.EMPTY : jsonEncode(val));
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////
}