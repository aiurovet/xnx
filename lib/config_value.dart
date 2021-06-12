import 'package:meta/meta.dart';
import 'package:doul/config_event.dart';

//////////////////////////////////////////////////////////////////////////////

class ConfigValue {
  bool hasData;
  String key;
  bool isEnabled;
  List<ConfigValue> list;
  Map<String, ConfigValue> map;
  final List<ConfigValue> listOfLists;
  final ConfigValue parent;
  ConfigEventResult parseResult;
  String text;
  ConfigDataParsed valueParsed;

  bool get isPlain => ((list == null) && (map == null));
  bool get isResettable => (parent != null) && (parseResult == ConfigEventResult.ok);

  var offset = 0;

  ConfigValue({Object key, @required Object data, this.parent, @required this.listOfLists, @required this.valueParsed}) {
    this.key = key.toString();
    isEnabled = true;
    valueParsed = valueParsed ?? parent?.valueParsed;

    if (valueParsed != null) {
      var configData = ConfigData(this.key, data);
      parseResult = valueParsed(configData);
      data = configData.data;
      this.key = configData.key;
    }

    hasData = (data != null);

    if (parseResult != ConfigEventResult.stop) {
      if (data is List) {
        list = [];

        for (var childData in data) {
          var ccv = ConfigValue(key: this.key, data: childData, parent: this, listOfLists: listOfLists, valueParsed: valueParsed);
          this.key = ccv.key;
          list.add(ccv);
        }
      }
      else if (data is Map<String, Object>) {
        map = {};

        data.forEach((childKey, childData) {
          var ccv = ConfigValue(key: childKey, data: childData, parent: this, listOfLists: listOfLists, valueParsed: valueParsed);
          map[ccv.key] = ccv;
        });
      }
      else {
        text = data?.toString();
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void disable() {
    isEnabled = false;

    if (list != null) {
      for (var v in list) {
        if (!v.isPlain) {
          v.disable();
        }
      }
    }
    if (map != null) {
      map.forEach((k, v) {
        if (!v.isPlain) {
          v.disable();
        }
      });
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void disableListsByKey(String key, ConfigValue value) {
    if (value?.parent?.key == key) {
      return;
    }

    var valuesToClear = listOfLists.where((x) =>
      x.isEnabled && (x.key == key) && ((value == null) || (x != value))
    ).toList();

    for (var x in valuesToClear) {
      x.disable();
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<ConfigValue> getListOfLists(ConfigValue value) {
    var listOfLists = <ConfigValue>[];

    var list = value?.list;

    if (list != null) {
      listOfLists.add(value);

      for (var i = 0, n = list.length; i < n; i++) {
        var childValue = list[i];

        if (childValue?.isPlain ?? false) {
          listOfLists.addAll(getListOfLists(childValue));
        }
      }
    }
    else {
      var map = value?.map;

      if (map != null) {
        map.forEach((childKey, childValue) {
          if (childValue?.isPlain ?? false) {
            listOfLists.addAll(getListOfLists(childValue));
          }
        });
      }
    }

    return listOfLists;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigEventResult getPlainValues(Map<String, String> plainValues) {
    var result = ConfigEventResult.ok;

    if (!isEnabled) {
      return result;
    }

    if (list?.isNotEmpty ?? false) {
      var isAdded = listOfLists.any((x) =>
        isEnabled && (x.key == key) && (x == this)
      );

      if (!isAdded) {
        listOfLists.add(this);
      }

      if (offset >= list.length) {
        offset = 0;
      }

      var childValue = list[offset];
      result = childValue.getPlainValues(plainValues);
    }
    else if (map != null) {
      map.forEach((childKey, childValue) {
        if (result != ConfigEventResult.ok) {
          return;
        }

        disableListsByKey(childKey, childValue);

        result = childValue.getPlainValues(plainValues);
      });
    }
    else {
      if (text != null) {
        plainValues[key] = text;
      }
      else {
        plainValues.remove(key);
        disableListsByKey(key, null);
      }

      result = parseResult;

      if (result == ConfigEventResult.reset) {
        resetAllLists();
        result = ConfigEventResult.ok;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  void resetAllLists() {
    for (var x in listOfLists) {
      if (x.isEnabled) {
        x.disable();
      }
    }

    listOfLists.clear();
  }

  //////////////////////////////////////////////////////////////////////////////

  @override String toString() {
    if (list != null) {
      return list.toString();
    }
    if (map != null) {
      return map.toString();
    }
    if (text != null) {
      return text;
    }

    return 'null';
  }
}

////////////////////////////////////////////////////////////////////////////////
