import 'dart:io';

import 'package:xnx/src/ext/string.dart';

class Logger {
  static const String STUB_LEVEL = '{L}';
  static const String STUB_MESSAGE = '{M}';
  static const String STUB_TIME = '{T}';

  static const String FORMAT_DEFAULT = '';
  static const String FORMAT_SIMPLE = '[$STUB_TIME] [$STUB_LEVEL] $STUB_MESSAGE';

  static const int LEVEL_SILENT = 0;
  static const int LEVEL_ERROR = 1;
  static const int LEVEL_OUT = 2;
  static const int LEVEL_WARNING = 3;
  static const int LEVEL_INFORMATION = 4;
  static const int LEVEL_DEBUG = 5;

  static const int LEVEL_DEFAULT = LEVEL_INFORMATION;

  static const LEVELS = [ 'quiet', 'errors', 'normal', 'warnings', 'info', 'debug' ];

  static final RegExp RE_PREFIX = RegExp(r'^', multiLine: true);

  String _format = FORMAT_DEFAULT;
  String get format => _format;
  set format(String? value) => _format = (value ?? FORMAT_DEFAULT);

  int _level = LEVEL_DEFAULT;
  int get level => _level;

  set level(int value) =>
    _level = value < 0 ? LEVEL_DEFAULT :
             value >= LEVEL_DEBUG ? LEVEL_DEBUG : value;

  set levelAsString(String value) {
    if (value.isBlank()) {
      _level = LEVEL_DEFAULT;
    }
    else {
      level = LEVELS.indexOf(value);

      if (_level < 0) {
        level = int.tryParse(value) ?? LEVEL_DEFAULT;
      }
    }
  }

  Logger([int? newLevel]) {
    level = newLevel ?? LEVEL_DEFAULT;
  }

  String? debug(String data) =>
    print(data, LEVEL_DEBUG);

  String? error(String data) =>
    print(data, LEVEL_ERROR);

  String? formatMessage(String msg, int level) {
    if ((level > _level) || (level < -_level) ||
        (level == LEVEL_SILENT) || (_level == LEVEL_SILENT)) {
      return null;
    }

    if (level == LEVEL_OUT) {
      return msg;
    }

    var now = DateTime.now().toString();
    var lvl = levelToString(level);
    var pfx = (_format.isEmpty ? _format : _format.replaceFirst(STUB_TIME, now).replaceFirst(STUB_LEVEL, lvl).replaceFirst(STUB_MESSAGE, msg));

    var msgEx = msg.replaceAll(RE_PREFIX, pfx);

    return msgEx;
  }

  IOSink getSink(int level) =>
      (level == LEVEL_OUT ? stdout : stderr);

  bool hasMinLevel(int minLevel) => (_level >= minLevel);

  bool get hasLevel => (_level != LEVEL_DEFAULT);

  bool get isDebug => (_level >= LEVEL_DEBUG);

  bool get isInfo => (_level >= LEVEL_INFORMATION);

  bool get isSilent => (_level == LEVEL_SILENT);

  bool get isUnknown => !hasLevel;

  String? information(String data) =>
    print(data, LEVEL_INFORMATION);

  static String levelToString(int level) {
    switch (level) {
      case LEVEL_DEBUG: return 'DBG';
      case LEVEL_ERROR: return 'ERR';
      case LEVEL_INFORMATION: return 'INF';
      case LEVEL_WARNING: return 'WRN';
      default: return '';
    }
  }

  String? out(String data) =>
    print(data, LEVEL_OUT);

  String? outInfo(String data) =>
    print(data, -LEVEL_OUT);

  String? print(String msg, int level) {
    var msgEx = formatMessage(msg, level);

    if (msgEx != null) {
      getSink(level).writeln(msgEx);
    }

    return msgEx;
  }

  String? warning(String data) =>
    print(data, LEVEL_WARNING);
}