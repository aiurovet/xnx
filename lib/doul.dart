import 'dart:io';

import 'convert.dart';
import 'ext/string.dart';
import 'logger.dart';
import 'options.dart';

class Doul {
  Logger _logger;

  Doul({Logger log = null}) {
    _logger = log ?? Logger();
  }

  static void main(List<String> args) {
    var isOK = false;
    var app = Doul();

    try {
      app.exec(args);
      isOK = true;
    }
    on Error catch (e, stackTrace) {
      isOK = app.onError(e?.toString(), stackTrace);
    }
    on Exception catch (e, stackTrace) {
      isOK = app.onError(e?.toString(), stackTrace);
    }

    exit(isOK ? 0 : 1);
  }

  void exec(List<String> args) {
    Convert(_logger).exec(args);
  }

  bool onError(String errMsg, StackTrace stackTrace) {
    if (StringExt.isNullOrBlank(errMsg)) {
      return false;
    }
    else {
      var errDecorRE = RegExp(r'^Exception[\:\s]*', caseSensitive: false);
      errMsg = errMsg.replaceFirst(errDecorRE, StringExt.EMPTY);

      if (errMsg == Options.HELP['name']) {
        return true;
      }
      else if (_logger.isSilent) {
        return false;
      }

      var errDtl = (_logger.level >= Logger.LEVEL_DEBUG ? '\n\n' + stackTrace?.toString() : StringExt.EMPTY);
      errMsg = '\n*** ERROR: ${errMsg}${errDtl}\n';

      _logger.error(errMsg);

      return false;
    }
  }
}