enum ConfigDataType {
  list,
  map,
  plain
}

////////////////////////////////////////////////////////////////////////////////

enum ConfigEventResult {
  drop, // drop all current lists to avoid old loops
  next, // move lists to the next combination of values
  ok, // continue as normal
  run, // ready to run command
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
