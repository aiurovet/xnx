import 'package:doul/config_event.dart';
import 'package:doul/config_value.dart';
import 'package:doul/ext/string.dart';
import 'package:doul/logger.dart';
import 'package:meta/meta.dart';

//////////////////////////////////////////////////////////////////////////////

class ConfigFeed {
  final List<ConfigValue> listOfLists = [];
  ConfigValue topValue;
  final ConfigDataParsed dataParsed;
  final ConfigMapExec mapExec;

  Logger _logger;

  //////////////////////////////////////////////////////////////////////////////

  ConfigFeed({
    @required this.dataParsed,
    @required this.mapExec,
    @required Logger logger
  }) {
    assert(dataParsed != null);
    assert(mapExec != null);

    _logger = logger;
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

      if (result == ConfigEventResult.stop) {
        break;
      }

var exe = plainValues['{run}'];

if (StringExt.isNullOrBlank(exe)) {
  exe = plainValues['{cmd}'];
}

_logger.outInfo('\n*** Command: ***\n$exe\n');

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