import 'dart:io';

import 'ext/string.dart';

class Log {
  static const String STUB_LEVEL = '{L}';
  static const String STUB_MESSAGE = '{M}';
  static const String STUB_TIME = '{T}';

  static const String FORMAT_DEFAULT = null;
  static const String FORMAT_SIMPLE = '[${STUB_TIME}] [${STUB_LEVEL}] ${STUB_MESSAGE}';

  static const int LEVEL_SILENT = 0;
  static const int LEVEL_ERROR = 1;
  static const int LEVEL_OUT = 2;
  static const int LEVEL_OUT_INFO = 3;
  static const int LEVEL_WARNING = 4;
  static const int LEVEL_INFORMATION = 5;
  static const int LEVEL_DEBUG = 6;

  static const int LEVEL_DEFAULT = LEVEL_OUT_INFO;

  static final RegExp RE_PREFIX = RegExp(r'^', multiLine: true);

  static String _format = FORMAT_DEFAULT;
  static String get format => _format;
  static set format(String value) => _format = (StringExt.isNullOrEmpty(value) ? null : value);

  static int _level = LEVEL_DEFAULT;
  static int get level => _level;

  static set level(int value) =>
    _level = value < 0 ? LEVEL_WARNING :
             value >= LEVEL_DEBUG ? LEVEL_DEBUG : value;

  static void debug(String data) {
    print(data, LEVEL_DEBUG);
  }

  static void error(String data) {
    print(data, LEVEL_ERROR);
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

  static bool get isDefault => (_level == LEVEL_DEFAULT);

  static bool get isDetailed => (_level >= LEVEL_INFORMATION);

  static bool get isSilent => (_level == LEVEL_SILENT);

  static bool get isUltimate => (_level >= LEVEL_DEBUG);

  static void information(String data) {
    print(data, LEVEL_INFORMATION);
  }

  static String levelToString(int level) {
    switch (level) {
      case LEVEL_DEBUG: return 'DBG';
      case LEVEL_ERROR: return 'ERR';
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
    if ((level > _level) || (msg == null)) {
      return;
    }

    if (level == LEVEL_OUT) {
      stdout.writeln(msg);
    }
    else {
      stderr.writeln(_format == null ? msg : formatMessage(msg));
    }
  }

  static void warning(String data) {
    print(data, LEVEL_WARNING);
  }
}