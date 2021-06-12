enum ConfigDataType {
  list,
  map,
  plain
}

////////////////////////////////////////////////////////////////////////////////

enum ConfigEventResult {
  exec, // ready to execute command
  ok, // continue as normal
  reset, // drop all current lists to avoid old loops
  stop, // stop immediately
}

////////////////////////////////////////////////////////////////////////////////

typedef ConfigDataParsed = ConfigEventResult Function(ConfigData data);
typedef ConfigMapExec = ConfigEventResult Function(Map<String, String> map);

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
    else {
      type = ConfigDataType.plain;
    }
  }
}
