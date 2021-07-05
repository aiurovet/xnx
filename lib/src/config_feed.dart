import 'package:doul/src/config_event.dart';
import 'package:doul/src/config_value.dart';
import 'package:meta/meta.dart';

//////////////////////////////////////////////////////////////////////////////

class ConfigFeed {
  final List<ConfigValue> listOfLists = [];
  ConfigValue lastValue;
  ConfigValue topValue;
  final ConfigDataParsed dataParsed;
  final ConfigMapExec mapExec;

  //////////////////////////////////////////////////////////////////////////////

  ConfigFeed({
    @required this.dataParsed,
    @required this.mapExec
  });

  //////////////////////////////////////////////////////////////////////////////

  ConfigEventResult exec(Object topData) {
    var result = ConfigEventResult.ok;

    topValue = ConfigValue(
      key: null,
      data: topData,
      parent: null,
      listOfLists: listOfLists,
      valueParsed: dataParsed
    );

    lastValue = topValue.getLastValue();
    listOfLists.clear();

    for (var plainValues = <String, String>{}; ;) {
      result = topValue.getPlainValues(plainValues);

      if (result == ConfigEventResult.stop) {
        break;
      }

      if (result == ConfigEventResult.run) {
        if (mapExec(plainValues) == ConfigEventResult.stop) {
          break;
        }
      }

      if (!next()) {
        break;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool next() {
    for (var i = listOfLists.length - 1; (i >= 0); --i) {
      var curr = listOfLists[i];

      if (!curr.isEnabled) {
        continue;
      }

      var list = curr.list;

      if (curr.offset < list.length) {
        if ((++curr.offset) < list.length) {
          return true;
        }
        if (i == 0) {
          if (!lastValue.isReached && listOfLists.isNotEmpty) {
            //listOfLists[0].offset = 0;
            listOfLists[0].restart();
            return true;
          }
        }
      }
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////
}