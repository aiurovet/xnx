import 'dart:io';

import 'package:xnx/src/convert.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';

class Xnx {
  Logger _logger = Logger();
  late final Convert _convert;

  Xnx({Logger? logger}) {
    Env.init();

    if (logger != null) {
      _logger = logger;
    }

    _convert = Convert(_logger);
  }

  void exec(List<String> args) =>
    _convert.exec(args);

  void finish(bool isOK) {
    if ((isOK && _convert.options.isWaitAlways) ||
        (!isOK && _convert.options.isWaitOnErr)) {
      stderr.writeln('\nPress <Enter> to complete...');
      stdin.readByteSync();
    }

    exit(isOK ? 0 : 1);
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

    app.finish(isOK);
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
      else if (errMsg == Options.help['name']) {
        return true;
      }
      else if (_logger.isSilent) {
        return false;
      }

      var errDtl = (_logger.level >= Logger.levelDebug ? '\n\n' + stackTrace.toString() : '');
      errMsg = '\n*** ERROR: $errMsg$errDtl\n';

      _logger.error(errMsg);

      return false;
    }
  }
}