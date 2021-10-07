import 'dart:io';

import 'package:xnx/src/convert.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';

class Xnx {
  Logger _logger = Logger();

  Xnx({Logger? logger}) {
    Env.init();

    if (logger != null) {
      _logger = logger;
    }
  }

  static void main(List<String> args) {
    var isOK = false;
    var app = Xnx();

    try {
      app.exec(args);
      isOK = true;
    }
    on Error catch (e, stackTrace) {
      isOK = app.onError(e.toString(), stackTrace);
    }
    on Exception catch (e, stackTrace) {
      isOK = app.onError(e.toString(), stackTrace);
    }

    exit(isOK ? 0 : 1);
  }

  void exec(List<String> args) {
    Convert(_logger).exec(args);
  }

  bool onError(String errMsg, StackTrace stackTrace) {
    if (errMsg.isBlank()) {
      return false;
    }
    else {
      var errDecorRE = RegExp(r'^(Exception[\:\s]*)+', caseSensitive: false);
      errMsg = errMsg.replaceFirst(errDecorRE, '');

      if (errMsg.isBlank()) {
        return false;
      }
      else if (errMsg == Options.HELP['name']) {
        return true;
      }
      else if (_logger.isSilent) {
        return false;
      }

      var errDtl = (_logger.level >= Logger.LEVEL_DEBUG ? '\n\n' + stackTrace.toString() : '');
      errMsg = '\n*** ERROR: $errMsg$errDtl\n';

      _logger.error(errMsg);

      return false;
    }
  }
}