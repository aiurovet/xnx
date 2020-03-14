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

  static const int LEVEL_DEFAULT = LEVEL_WARNING;

  static const int USER_LEVEL_SILENT = 0;
  static const int USER_LEVEL_DEFAULT = 1;
  static const int USER_LEVEL_DETAILED = 2;
  static const int USER_LEVEL_ULTIMATE = 3;

  static final RegExp RE_PREFIX = RegExp('^', multiLine: true);

  static int _level = LEVEL_DEFAULT;

  static void debug(String data) {
    print(data, LEVEL_DEBUG);
  }

  static void error(String data) {
    print(data, LEVEL_ERROR);
  }

  static void fatal(String data) {
    print(data, LEVEL_FATAL);
  }

  static int getLevel() {
    return _level;
  }

  static bool hasMinLevel(int minLevel) {
    return (_level >= minLevel);
  }

  static bool isDetailed() {
    return (_level >= LEVEL_INFORMATION);
  }

  static bool isDefault() {
    return (_level == LEVEL_DEFAULT);
  }

  static bool isSilent() {
    return (_level == LEVEL_SILENT);
  }

  static bool isUltimate() {
    return (_level >= LEVEL_DEBUG);
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
    else if (level <= _level) {
      var now = DateTime.now().toString();
      var lvl = levelToString(level);
      var pfx = '[${now}] [${lvl}] ';

      var msgEx = msg.replaceAll(RE_PREFIX, pfx);
      stderr.writeln(msgEx);
    }
  }

  static void setLevel(int level) {
    if (level < 0) {
      _level = LEVEL_WARNING;
    }
    else if (_level >= LEVEL_DEBUG) {
      _level = LEVEL_DEBUG;
    }
    else {
      _level = level;
    }
  }

  static void setUserLevel(int userLevel) {
    if (userLevel <= USER_LEVEL_SILENT) {
      _level = LEVEL_SILENT;
    }
    else if (userLevel >= USER_LEVEL_ULTIMATE) {
      _level = LEVEL_DEBUG;
    }
    else if (userLevel == USER_LEVEL_DETAILED) {
      _level = LEVEL_INFORMATION;
    }
    else {
      _level = LEVEL_WARNING;
    }
  }

  static void warning(String data) {
    print(data, LEVEL_WARNING);
  }
}