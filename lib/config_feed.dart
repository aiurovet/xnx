import 'package:doul/config_event.dart';
import 'package:doul/config_value.dart';
import 'package:doul/ext/string.dart';
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

var key = '{run}';
var run = (plainValues.containsKey(key) ? plainValues[key] : null) ?? StringExt.EMPTY;

if (run.startsWith('{sub} --move')) {
  print('\n*** Result: $result\n*** Run: $run\n');
}

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
      }
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////
}