import 'package:doul/ext/string.dart';

class ConfigFileInfo {

  //////////////////////////////////////////////////////////////////////////////

  static final RegExp PATH_RE = RegExp(r'(.*)(path\=)(.*)', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  var filePath = StringExt.EMPTY;
  var jsonPath = StringExt.EMPTY;

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileInfo([String input]) {
    parse(input);
  }

  //////////////////////////////////////////////////////////////////////////////

  void init({String initFilePath, String initJsonPath, String initKey, String options}) {
    filePath = initFilePath?.trim() ?? StringExt.EMPTY;
    jsonPath = initJsonPath?.trim() ?? StringExt.EMPTY;
  }

  //////////////////////////////////////////////////////////////////////////////

  void parse(String input) {
    var foundAt = input?.indexOf('?') ?? -1;

    if (foundAt < 0) {
      init(initFilePath: input);
      return;
    }

    filePath = input.substring(0, foundAt);

    var filters = input.substring(foundAt + 1);
    var match = PATH_RE.firstMatch(filters);

    if ((match?.start ?? -1) >= 0) {
      jsonPath = match.group(3);
    }
  }

  //////////////////////////////////////////////////////////////////////////////
}