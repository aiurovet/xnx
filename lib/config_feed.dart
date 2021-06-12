import 'package:doul/config_event.dart';
import 'package:doul/config_value.dart';
import 'package:meta/meta.dart';

//////////////////////////////////////////////////////////////////////////////

class ConfigFeed {
  final List<ConfigValue> listOfLists = [];
  ConfigValue topValue;
  final ConfigDataParsed dataParsed;
  final ConfigMapExec mapExec;

  //////////////////////////////////////////////////////////////////////////////

  ConfigFeed({
    @required this.dataParsed,
    @required this.mapExec
  }) {
    assert(dataParsed != null);
    assert(mapExec != null);
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigEventResult exec(Object topData) {
    // if ((topData is Map) && (topData.length == 1)) {
    //   return exec(topData.values.elementAt(0));
    // }

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
        result = mapExec(plainValues);

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
    for (var i = listOfLists.length - 1; (i >= 0); --i) {
      var curr = listOfLists[i];

      if (!curr.isEnabled) {
        continue;
      }

      if ((++curr.offset) < curr.list.length) {
        return true;
      }
      else if (i == 0) {
        return false;
      }
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////
}