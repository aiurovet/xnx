import 'dart:io';

import 'ext/string.dart';

class Log {
  static const int LEVEL_OUT = -1;
  static const int LEVEL_SILENT = 0;
  static const int LEVEL_FATAL = 2;
  static const int LEVEL_ERROR = 3;
  static const int LEVEL_WARNING = 4;
  static const int LEVEL_INFORMATION = 5;
  static const int LEVEL_DEBUG = 6;

  static final RegExp RE_PREFIX = RegExp('^', multiLine: true);

  static int level;

  static void debug(String data) {
    print(data, LEVEL_DEBUG);
  }

  static void error(String data) {
    print(data, LEVEL_ERROR);
  }

  static void fatal(String data) {
    print(data, LEVEL_FATAL);
  }

  static void information(String data) {
    print(data, LEVEL_INFORMATION);
  }

  static String levelToString(int level) {
    switch (level) {
      case LEVEL_DEBUG: return 'DBG';
      case LEVEL_ERROR: return 'ERR';
      case LEVEL_FATAL: return 'FTL';
      case LEVEL_INFORMATION: return 'INF';
      case LEVEL_WARNING: return 'WRN';
      default: return StringExt.EMPTY;
    }
  }

  static void out(String data) {
    print(data, LEVEL_OUT);
  }

  static void print(String msg, int level) {
    if ((level == LEVEL_SILENT) || (msg == null)) {
      return;
    }

    if (level == LEVEL_OUT) {
      stdout.writeln(msg);
    }
    else if (level <= Log.level) {
      var now = DateTime.now().toString();
      var lvl = levelToString(level);
      var pfx = '[${now} ${lvl}] ';

      var msgEx = msg.replaceAll(RE_PREFIX, pfx);
      stderr.writeln(msgEx);
    }
  }

  static void warning(String data) {
    print(data, LEVEL_WARNING);
  }
}