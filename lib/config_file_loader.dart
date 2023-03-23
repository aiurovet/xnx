import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:file/file.dart';

import 'package:json5/json5.dart';
import 'package:json_path/json_path.dart';
import 'package:thin_logger/thin_logger.dart';
import 'package:xnx/command.dart';

import 'package:xnx/config_file_info.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/keywords.dart';
import 'package:xnx/ext/file.dart';
import 'package:xnx/ext/stdin.dart';
import 'package:xnx/ext/string.dart';

class ConfigFileLoader {
  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String impFileKeySep = '_';
  static const String impFindPrefix = '+'; // import if exists
  static const String impTempPrefix = '-'; // import if exists and delete after
  static const String recordSep = ',';

  static final String allArgs = r'${@}';
  static final RegExp rexCmdLineArgs = RegExp(r'(\$\*|\$\@|\$\{\*\}|\${\@\})|(\$~([0-9]+))|(\$\{~([1-9][0-9]*)\})');
  static final RegExp rexImpFileKeyBadChars = RegExp(r'[\\\/\.,;]');
  static final RegExp rexJsonMapBraces = RegExp(r'^[\s\{]+|[\s\}]+$');

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  Logger _logger = Logger();

  Object? _data;
  Object? get data => _data;

  File? _file;
  File? get file => _file;

  String _importDirName = '';
  String get importDirName => _importDirName;

  bool _isStdIn = false;
  bool get isStdIn => _isStdIn;

  int _lastModifiedStamp = 0;
  int get lastModifiedStamp => _lastModifiedStamp;

  String _text = '';
  String get text => _text;

  //////////////////////////////////////////////////////////////////////////////
  // Internals
  //////////////////////////////////////////////////////////////////////////////

  @protected late final Keywords keywords;

  //////////////////////////////////////////////////////////////////////////////
  // Construction
  //////////////////////////////////////////////////////////////////////////////

  ConfigFileLoader({bool isStdIn = false, File? file, String? text, String? importDirName, Keywords? keywords, Logger? logger}) {
    _file = file;
    _isStdIn = isStdIn;
    _lastModifiedStamp = (file?.lastModifiedStampSync() ?? 0);

    if (importDirName != null) {
      _importDirName = importDirName;
    }

    if (text != null) {
      _text = text;
    }

    if (keywords != null) {
      this.keywords = keywords;
    }

    if (logger != null) {
      _logger = logger;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void clear({bool isFull = true}) {
    _data = null;
    _file = null;
    _importDirName = '';
    _isStdIn = false;
    _text = '';

    if (isFull) {
      _lastModifiedStamp = 0;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void expandCmdLineArgs(List<String>? args) {
    if ((args != null) && args.isEmpty) {
      args = null;
    }

    var argCount = (args?.length ?? 0);
    var startCmd = Command.getStartCommand(escapeQuotes: true);

    _text = _text.replaceAll('\$\$', '\x01');
    _text = _text.replaceAllMapped(rexCmdLineArgs, (match) {
      if (match.group(1) != null) {
        return allArgs; // will be expanded later
      }

      var envArgNo = (match.group(3) ?? match.group(5));

      if (envArgNo != null) {
        var argNo = (int.tryParse(envArgNo) ?? -1);

        if (argNo == 0) {
          return startCmd.replaceAll(Env.escape, Env.escapeEscape);
        }

        if ((args != null) && (argNo > 0) && (argNo <= argCount)) {
          return args[argNo - 1].replaceAll(Env.escape, Env.escapeEscape);
        }
      }

      return '';
    });
    _text = _text.replaceAll('\x01', '\$');
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getImportFileKey(String prefix, {String? impPath}) {
    var key = '';

    if (prefix.isBlank()) {
      key += prefix;
    }

    if ((impPath != null) && !impPath.isBlank()) {
      key += impFileKeySep;
      key += impPath.replaceAll(rexImpFileKeyBadChars, impFileKeySep);
    }

    return key;
  }

  //////////////////////////////////////////////////////////////////////////////

  String importFiles(String paramNameImport, {String? impPath, String? impPathsSerialized}) {
    try {
      var fullText = '';
      var keyPrefix = 'import';

      if ((impPath != null) && !impPath.isBlank()) {
        loadSync(impPath);
        fullText = text;
      }
      else {
        var jsonData = json5Decode('{"$paramNameImport": $impPathsSerialized}');
        var jsonText = '';
        var impPaths = jsonData[paramNameImport];

        if ((impPaths == null) || impPaths.isEmpty) {
          impPath = null;
        }
        else {
          if (impPaths is List) {
            fullText += '{';

            for (var impPathEx in impPaths) {
              loadSync(impPathEx);

              if (fullText.length > 1) {
                fullText += recordSep;
              }

              var key = getImportFileKey(keyPrefix, impPath: impPathEx);
              var map = <String, Object?>{};
              map[key] = json5Decode(text);

              jsonText = jsonEncode(map)
                  .replaceAll(rexJsonMapBraces, '');
              fullText += jsonText;
            }

            fullText += '}';

            impPath = impPaths[0];
          }
        }
      }

      if (impPath == null) {
        return '';
      }

      clear(isFull: false);

      var result = '"${getImportFileKey(keyPrefix, impPath: impPath)}": $fullText';

      return result;
    }
    catch (e) {
      throw Exception('Failed to parse file: "$impPath"\n\n${e.toString()}');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileLoader loadImportsSync() {
    if (keywords.forImport.isBlank()) {
      return this;
    }

    var paramPattern = RegExp.escape(keywords.forImport);
    var pattern = "('$paramPattern[^']*'|\"$paramPattern[^\"]*\")";
    pattern += r'\s*:\s*((\"(.*?)\")|(\[[^\]]+\]))\s*([,\]\}]|\/\/|\/\*)';

    var regExp = RegExp(pattern);

    if (!regExp.hasMatch(_text)) {
      return this;
    }

    var lf = ConfigFileLoader(keywords: keywords, logger: _logger);

    _text = _text.replaceAll(Env.escapeEscape, '\x01');
    _text = _text.replaceAll(Env.escapeApos, '\x02');
    _text = _text.replaceAll(Env.escapeQuot, '\x03');
    _text = _text.replaceAllMapped(regExp, (match) {
      var impName = match.group(4);

      if ((impName == null) || impName.isEmpty) {
        return match.group(0) ?? '';
      }

      final isTemp = impName.startsWith(impTempPrefix);
      final isOptional = (isTemp || impName.startsWith(impFindPrefix));

      if (isOptional) {
        impName = impName.substring(impTempPrefix.length);
      }

      final impPath = Path.join(_importDirName, impName);

      if (isOptional && !Path.fileSystem.file(impPath).existsSync()) {
        return match.group(0) ?? '';
      }

      final impPathsSerialized = match.group(5);
      final elemSep = match.group(6) ?? '';

      final result = lf.importFiles(keywords.forImport, impPath: impPath, impPathsSerialized: impPathsSerialized) + elemSep;

      if (_lastModifiedStamp < lf._lastModifiedStamp) {
        _lastModifiedStamp = lf._lastModifiedStamp;
      }

      if (isTemp) {
        Path.fileSystem.file(impPath).deleteSync();
      }

      return result;
    });
    _text = _text.replaceAll('\x03', Env.escapeQuot);
    _text = _text.replaceAll('\x02', Env.escapeApos);
    _text = _text.replaceAll('\x01', Env.escapeEscape);

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Methods
  //////////////////////////////////////////////////////////////////////////////

  ConfigFileLoader loadJsonSync(ConfigFileInfo fileInfo, {List<String>? appPlainArgs}) {
    loadSyncEx(fileInfo);

    if (!keywords.forImport.isBlank()) {
      loadImportsSync();
    }

    //expandCmdLineArgs(appPlainArgs);
    _text = Env.expand(_text, args: appPlainArgs, canEscape: true);

    _data = json5Decode(_text);
    _text = '';

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileLoader loadSync(String? pathAndFilter) {
    return loadSyncEx(ConfigFileInfo(input: pathAndFilter));
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileLoader loadSyncEx(ConfigFileInfo fileInfo) {
    var filePath = fileInfo.filePath;

    _isStdIn = (filePath.isBlank() || (filePath == StringExt.stdinPath));
    var displayName = (_isStdIn ? StringExt.stdinDisplay : '"$filePath"');

    _importDirName = fileInfo.importDirName;

    _logger.info('Loading from $displayName');

    if (_isStdIn) {
      _file = null;
      _text = stdin.readAsStringSync();
    }
    else {
      var file = Path.fileSystem.file(filePath);
      var stat = file.statSync();

      if (stat.type == FileSystemEntityType.notFound) {
        throw Exception(Path.appendCurDirIfPathIsRelative('File is not found: ', displayName));
      }

      var fileLastModifiedStamp = stat.modified.millisecondsSinceEpoch;

      if (_lastModifiedStamp < fileLastModifiedStamp) {
        _lastModifiedStamp = fileLastModifiedStamp;
      }

      _file = file;
      _text = file.readAsStringSync();
    }

    _text = makeRepeatableKeysUnique(_text);

    if (fileInfo.jsonPath.isEmpty) {
      _data = json5Decode(_text);
      _text = jsonEncode(_data);
    }
    else {
      var data = <Object?>[];

      var jsonPath = JsonPath(fileInfo.jsonPath);
      var decoded = json5Decode(_text);

      if (decoded != null) {
        data.addAll(jsonPath.read(decoded).map((x) => x.value));
        _data = data;
      }

      _text = (data.isEmpty ? '' : jsonEncode(_data));
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  String makeRepeatableKeysUnique(String text) {
    if (keywords.rexRepeatable.pattern.isEmpty) {
      return text;
    }

    var i = 0;

    var result = text
      .replaceAll(r'\\', '\x01')
      .replaceAll(r"\'", '\x02')
      .replaceAll(r'\"', '\x03')
      .replaceAllMapped(keywords.rexRepeatable, (match) {
        return '${match.group(1)}^${(++i).toString().padLeft(5, '0')}${match.group(2)}';
      })
      .replaceAll('\x03', r'\"')
      .replaceAll('\x02', r"\'")
      .replaceAll('\x01', r'\\')
    ;

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}
