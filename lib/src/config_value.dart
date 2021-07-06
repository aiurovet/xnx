import 'package:meta/meta.dart';
import 'package:doul/src/config_event.dart';

//////////////////////////////////////////////////////////////////////////////

class ConfigValue {
  static const dropKeyError = 'Drop key should have either string value or an array of string values';

  bool hasData;
  String key;
  bool isEnabled;
  bool isReached;
  List<ConfigValue> list;
  Map<String, ConfigValue> map;
  final List<ConfigValue> listOfLists;
  final ConfigValue parent;
  ConfigEventResult parseResult;
  String text;
  ConfigDataParsed valueParsed;

  bool get isPlain => ((list == null) && (map == null));
  bool get isResettable => (this != listOfLists?.first);

  var offset = 0;

  ConfigValue({
    @required Object key,
    @required Object data,
    @required this.parent,
    @required this.listOfLists,
    @required this.valueParsed
  }) {
    this.key = key.toString();
    isEnabled = true;
    isReached = false;
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
      else if ((data is num) && ((data % 1) == 0)) {
        text = data.toStringAsFixed(0);
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

  void disableByKey(String key, ConfigValue value, {Map<String, String> plainValues, bool isParentKeyChecked = true}) {
    if (isParentKeyChecked ?? true) {
      if (value?.parent?.key == key) {
        return;
      }
    }

    plainValues?.remove(key);

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

  ConfigValue getLastValue() {
    if (list != null) {
      return list.last.getLastValue();
    }
    else if (map != null) {
      return map.values.last.getLastValue();
    }
    else {
      return this;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigEventResult getPlainValues(Map<String, String> plainValues) {
    isReached = true;

    var isDrop = (parseResult == ConfigEventResult.drop);
    var result = ConfigEventResult.ok;

    if (!isEnabled) {
      return result;
    }

    if (list?.isNotEmpty ?? false) {
      if (isDrop) {
        for (var x in list) {
          if (x.isPlain) {
            disableByKey(x.text, null, plainValues: plainValues, isParentKeyChecked: false);
          }
          else {
            throw Exception(dropKeyError);
          }
        }

        result = ConfigEventResult.ok;
      }
      else {
        var isAdded = listOfLists.any((x) => (x.key == key) && (x == this));

        if (!isAdded) {
          listOfLists.add(this);
        }

        if ((offset >= list.length) && isResettable) {
          //offset = 0;
          restart();
        }

        if (offset < list.length) {
          var childValue = list[offset];
          result = childValue.getPlainValues(plainValues);
        }
        else if (!isResettable) {
          result = ConfigEventResult.stop;
        }
      }
    }
    else if (map != null) {
      if (isDrop) {
        throw Exception(dropKeyError);
      }

      map.forEach((childKey, childValue) {
        if (result != ConfigEventResult.ok) {
          return;
        }

        result = childValue.getPlainValues(plainValues);
      });
    }
    else {
      if (isDrop) {
        if (isPlain) {
          disableByKey(text, null, plainValues: plainValues, isParentKeyChecked: false);
        }
        else {
          throw Exception(dropKeyError);
        }

        result = ConfigEventResult.ok;
      }
      else {
        if (text != null) {
          plainValues[key] = text;
        }
        else {
          disableByKey(key, null, plainValues: plainValues, isParentKeyChecked: true);
        }

        result = parseResult;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  void restart() {
    isEnabled = true;
    isReached = false;
    offset = 0;

    if (list != null) {
      for (var v in list) {
        v.restart();
      }
    }
    if (map != null) {
      map.forEach((k, v) {
        v.restart();
      });
    }
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
