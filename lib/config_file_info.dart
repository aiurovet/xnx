import 'package:doul/ext/string.dart';

class ConfigFileInfo {

  //////////////////////////////////////////////////////////////////////////////

  static const String OPT_IGNORE_CASE = 'i';
  static const String OPT_REG_EXP = 'r';

  //////////////////////////////////////////////////////////////////////////////

  static final RegExp OPTS_RE = RegExp(r'(.*)(flags\=)([' + OPT_IGNORE_CASE + OPT_REG_EXP + r']+)(.*)', caseSensitive: false);
  static final RegExp KEY_RE = RegExp(r'(.*)(key\=)(.*)', caseSensitive: false);
  static final RegExp PATH_RE = RegExp(r'(.*)(path\=)([^&]+)(.*)', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  var filePath = StringExt.EMPTY;
  var jsonPath = StringExt.EMPTY;
  var isIgnoreCase = false;
  var isRegExp = false;

  RegExp keyRegExp;
  String keyString;
  bool get hasKey => (keyRegExp != null) || (keyString?.isNotEmpty ?? false);

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileInfo([String input]) {
    parse(input);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool hasMatch(String input) {
    if (input == null) {
      return false;
    }
    if (keyRegExp != null) {
      return keyRegExp.hasMatch(input);
    }
    if (isIgnoreCase) {
      return (keyString.compareTo(input.toLowerCase()) == 0);
    }
    else {
      return (keyString.compareTo(input) == 0);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void init({String initFilePath, String initJsonPath, String initKey, String options}) {
    filePath = initFilePath?.trim() ?? StringExt.EMPTY;
    jsonPath = initJsonPath?.trim() ?? StringExt.EMPTY;

    setKey(initKey?.trim() ?? StringExt.EMPTY, options: options);
  }

  //////////////////////////////////////////////////////////////////////////////

  void parse(String input) {
    var foundAt = input?.indexOf('?') ?? -1;

    if (foundAt < 0) {
      init(initFilePath: input);
      return;
    }

    filePath = input.substring(0, foundAt);
    var key = null;

    var filters = input.substring(foundAt + 1);
    var match = OPTS_RE.firstMatch(filters);
    var start = (match?.start ?? -1);

    String subFilterKey;
    String subFilterValue;

    if (start >= 0) {
      subFilterKey = match.group(2);
      subFilterValue = match.group(3);

      setOptions(subFilterValue);
      filters = filters.replaceFirst(subFilterKey + subFilterValue, StringExt.EMPTY);
    }

    match = PATH_RE.firstMatch(filters);
    start = (match?.start ?? -1);

    if (start >= 0) {
      subFilterKey = match.group(2);
      jsonPath = match.group(3);

      filters = filters.replaceFirst(subFilterKey + jsonPath, StringExt.EMPTY);
    }

    match = KEY_RE.firstMatch(filters);
    start = (match?.start ?? -1);

    if (start >= 0) {
      key = match.group(3);
    }

    setKey(key);
  }

  //////////////////////////////////////////////////////////////////////////////

  void setKey(String key, {String options}) {
    if (options != null) {
      setOptions(options);
    }
    if (isRegExp) {
      keyRegExp = RegExp(key, caseSensitive: !isIgnoreCase);
      keyString = null;
    }
    else {
      keyRegExp = null;
      keyString = (isIgnoreCase ? key.toLowerCase() : key);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setOptions(String options) {
    if (options == null) {
      isIgnoreCase = false;
      isRegExp = false;
    }
    else {
      isIgnoreCase = options.contains(OPT_IGNORE_CASE);
      isRegExp = options.contains(OPT_REG_EXP);
    }
  }

  //////////////////////////////////////////////////////////////////////////////
}