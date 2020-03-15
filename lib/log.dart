import 'dart:io';

import 'ext/string.dart';

class Log {
  static const String STUB_LEVEL = '{L}';
  static const String STUB_MESSAGE = '{M}';
  static const String STUB_TIME = '{T}';

  static const String FORMAT_DEFAULT = null;
  static const String FORMAT_SIMPLE = '[${STUB_TIME}] [${STUB_LEVEL}] ${STUB_MESSAGE}';

  static const int LEVEL_OUT_INFO = -2;
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

  static String _format = FORMAT_DEFAULT;
  static String get format => _format;
  static void set format(String value) => _format = (StringExt.isNullOrEmpty(value) ? null : value);

  static int _level = LEVEL_DEFAULT;
  static int get level => _level;

  static void set level(int value) =>
    _level = value < 0 ? LEVEL_WARNING :
             value >= LEVEL_DEBUG ? LEVEL_DEBUG : value;

  static int get userLevel =>
    _level == LEVEL_SILENT ? USER_LEVEL_SILENT :
    _level >= LEVEL_DEBUG ? USER_LEVEL_ULTIMATE :
    _level >= LEVEL_INFORMATION ? USER_LEVEL_DETAILED : USER_LEVEL_DEFAULT;

  static void set userLevel(int value) =>
    _level = value <= USER_LEVEL_SILENT ? LEVEL_SILENT :
             value >= USER_LEVEL_ULTIMATE ? LEVEL_DEBUG :
             value == USER_LEVEL_DETAILED ? LEVEL_INFORMATION : LEVEL_WARNING;

  static void debug(String data) {
    print(data, LEVEL_DEBUG);
  }

  static void error(String data) {
    print(data, LEVEL_ERROR);
  }

  static void fatal(String data) {
    print(data, LEVEL_FATAL);
  }

  static String formatMessage(String msg) {
    if (msg == null) {
      return msg;
    }

    var now = DateTime.now().toString();
    var lvl = levelToString(level);
    var pfx = (StringExt.isNullOrEmpty(_format) ? StringExt.EMPTY : _format.replaceFirst(STUB_TIME, now).replaceFirst(STUB_LEVEL, lvl).replaceFirst(STUB_MESSAGE, msg));

    var msgEx = msg.replaceAll(RE_PREFIX, pfx);

    return msgEx;
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

  static void outInfo(String data) {
    print(data, LEVEL_OUT_INFO);
  }

  static void print(String msg, int level) {
    if (((_level == LEVEL_SILENT) && (level != LEVEL_OUT)) || (level == LEVEL_SILENT) || (msg == null)) {
      return;
    }

    if (level == LEVEL_OUT) {
      stdout.writeln(msg);
    }
    else if (level == LEVEL_OUT_INFO) {
      stderr.writeln(msg);
    }
    else if (level <= _level) {
      stderr.writeln(_format == null ? msg : formatMessage(msg));
    }
  }

  static void warning(String data) {
    print(data, LEVEL_WARNING);
  }
}