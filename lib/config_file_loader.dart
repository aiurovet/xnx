import 'dart:convert';
import 'dart:io';

import 'package:doul/config_file_info.dart';
import 'package:json_path/json_path.dart';

import 'package:doul/log.dart';
import 'package:doul/ext/file.dart';
import 'package:doul/ext/stdin.dart';
import 'package:doul/ext/string.dart';

class ConfigFileLoader {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String IMP_FILE_KEY_SEP = '_';
  static const String RECORD_SEP = ',';

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

  ConfigFileLoader({bool isStdIn, File file, String text}) {
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
            fullText += RECORD_SEP;
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

  ConfigFileLoader loadImportsSync(String paramNameImport) {
    if (StringExt.isNullOrBlank(paramNameImport)) {
      return this;
    }

    var pattern = r'([\{\[\,])\s*\"' + RegExp.escape(paramNameImport) + r'\"\s*\:\s*((\"(.*?)\")|(\[[^\]]+\]))\s*([,\]\}])';
    var regExp = RegExp(pattern);

    if (!regExp.hasMatch(_text)) {
      return this;
    }

    var lf = ConfigFileLoader();

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

  ConfigFileLoader loadJsonSync(ConfigFileInfo fileInfo, {String paramNameImport, List<String> appPlainArgs}) {
    loadSyncEx(fileInfo);

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

  ConfigFileLoader loadSync(String pathAndFilter) {
    return loadSyncEx(ConfigFileInfo(pathAndFilter));
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileLoader loadSyncEx(ConfigFileInfo fileInfo) {
    var filePath = fileInfo.filePath;

    _isStdIn = (StringExt.isNullOrBlank(filePath) || (filePath == StringExt.STDIN_PATH));
    var displayName = (_isStdIn ? filePath : '"' + filePath + '"');

    Log.information('Loading ${displayName}');

    _file = (_isStdIn ? null : File(filePath));

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

    if (fileInfo.jsonPath.isEmpty) {
      _data = jsonDecode(_text);
    }
    else {
      var data = <Object>[];

      var jsonPath = JsonPath(fileInfo.jsonPath);
      var decoded = jsonDecode(_text);

      if ((jsonPath != null) && (decoded != null)) {
        data.addAll(jsonPath.read(decoded).map((x) => x.value));

        _data = data;
        _text = (data.isEmpty ? StringExt.EMPTY : jsonEncode(_data));
      }
    }

    //filterDataByKey(fileInfo, _data);

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////
}