enum ConfigDataType {
  list,
  map,
  none,
  plain
}

////////////////////////////////////////////////////////////////////////////////

enum ConfigEventResult {
  exec, // ready to run command and to go to the next list item
  next, // drop this list item and go to the next one
  ok, // continue as normal
  stop, // stop immediately
}

////////////////////////////////////////////////////////////////////////////////

typedef ConfigDataParsed = ConfigEventResult Function(ConfigData data);
typedef ConfigMapReady = ConfigEventResult Function(Map<String, String> map);

////////////////////////////////////////////////////////////////////////////////

class ConfigData {
  String key;
  Object data;
  ConfigDataType type;

  ConfigData(this.key, Object data) {
    this.data = data;

    if (data is List) {
      type = ConfigDataType.list;
    }
    else if (data is Map) {
      type = ConfigDataType.map;
    }
    else if (data == null) {
      type = ConfigDataType.none;
    }
    else {
      type = ConfigDataType.plain;
    }
  }
}
