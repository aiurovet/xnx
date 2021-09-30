
class ConfigFileInfo {

  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _RE_PATH = RegExp(r'(.*)(path\=)(.*)', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  var filePath = '';
  var jsonPath = '';

  //////////////////////////////////////////////////////////////////////////////

  ConfigFileInfo([String? input]) {
    parse(input);
  }

  //////////////////////////////////////////////////////////////////////////////

  void init({String? filePath, String? jsonPath}) {
    this.filePath = filePath?.trim() ?? '';
    this.jsonPath = jsonPath?.trim() ?? '';
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
      var match = _RE_PATH.firstMatch(filters);

      if ((match != null) && (match.start >= 0)) {
        jsonPath = (match.group(3) ?? '');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
}