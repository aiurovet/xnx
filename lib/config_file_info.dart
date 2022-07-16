
import 'package:xnx/ext/path.dart';

class ConfigFileInfo {

  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _rexPath = RegExp(r'(.*)(path\=)(.*)', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  var filePath = '';
  var jsonPath = '';
  var importDirName = '';

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileInfo({String? input, String? importDirName}) {
    if (importDirName != null) {
      this.importDirName = importDirName;
    }
    parse(input);
  }

  //////////////////////////////////////////////////////////////////////////////

  void init({String? filePath, String? jsonPath, String? importDirName}) {
    this.filePath = filePath?.trim() ?? '';
    this.jsonPath = jsonPath?.trim() ?? '';

    this.importDirName = importDirName ?? Path.fileSystem.path.dirname(this.filePath);
  }

  //////////////////////////////////////////////////////////////////////////////

  void parse(String? input) {
    var foundAt = input?.indexOf('?') ?? -1;

    if (foundAt < 0) {
      init(filePath: input);
      return;
    }

    if (input == null) {
      filePath = '';
      jsonPath = '';
    }
    else {
      filePath = input.substring(0, foundAt);

      var filters = input.substring(foundAt + 1);
      var match = _rexPath.firstMatch(filters);

      if ((match != null) && (match.start >= 0)) {
        jsonPath = (match.group(3) ?? '');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
}