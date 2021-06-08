import 'package:doul/config_event.dart';
//import 'package:doul/config_offset_list.dart';
import 'package:doul/config_value.dart';
import 'package:meta/meta.dart';

//////////////////////////////////////////////////////////////////////////////

class ConfigFeed {
  final List<ConfigValue> listOfLists = [];
  ConfigValue topValue;
  final ConfigDataParsed dataParsed;
  final ConfigMapReady mapReady;

  //////////////////////////////////////////////////////////////////////////////

  ConfigFeed({
    @required this.dataParsed,
    @required this.mapReady
  }) {
    assert(dataParsed != null);
    assert(mapReady != null);
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigEventResult exec(Object topData) {
    if ((topData is Map) && (topData.length == 1)) {
      return exec(topData.values.elementAt(0));
    }

    var result = ConfigEventResult.ok;

    topValue = ConfigValue(
      key: null,
      data: topData,
      parent: null,
      listOfLists: listOfLists,
      valueParsed: dataParsed
    );

    listOfLists.clear();

    for (var plainValues = <String, String>{}; ;) {
      result = topValue.getPlainValues(plainValues);

      if (result == ConfigEventResult.stop) {
        break;
      }
      else if (result == ConfigEventResult.exec) {
        if (plainValues.isNotEmpty) {
          var dbgMap = <String, String>{};

          dbgMap.addAll(plainValues);

          if (dbgMap.isNotEmpty) {
            dbgMap.removeWhere((key, value) => !'{d}{D}{r}{m}{k}'.contains(key));
            print(dbgMap.toString());
          }
        }

        result = mapReady(plainValues);

        if (result == ConfigEventResult.stop) {
          break;
        }

        if (!shift()) {
          break;
        }
      }
      else {
        break;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool shift() {
    for (var i = listOfLists.length - 1; ; --i) {
      var curr = listOfLists[i];

      if (!curr.isActive) {
        continue;
      }

      if ((++curr.offset) < curr.list.length) {
        return true;
      }
      else if (i == 0) {
        return false;
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
}