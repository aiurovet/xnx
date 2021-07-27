import 'dart:io';

import 'package:xnx/src/convert.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';

class Xnx {
  Logger _logger;

  Xnx({Logger logger}) {
    _logger = logger ?? Logger();
  }

  static void main(List<String> args) {
    var isOK = false;
    var app = Xnx();

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

      if (StringExt.isNullOrBlank(errMsg)) {
        return false;
      }
      else if (errMsg == Options.HELP['name']) {
        return true;
      }
      else if (_logger.isSilent) {
        return false;
      }

      var errDtl = (_logger.level >= Logger.LEVEL_DEBUG ? '\n\n' + stackTrace?.toString() : StringExt.EMPTY);
      errMsg = '\n*** ERROR: $errMsg$errDtl\n';

      _logger.error(errMsg);

      return false;
    }
  }
}