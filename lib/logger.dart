import 'dart:io';

import 'package:xnx/ext/string.dart';

class Logger {
  static const String stubLevel = '{L}';
  static const String stubMessage = '{M}';
  static const String stubTime = '{T}';

  static const String formatDefault = '';
  static const String formatSimple = '[$stubTime] [$stubLevel] $stubMessage';

  static const int levelSilent = 0;
  static const int levelError = 1;
  static const int levelOut = 2;
  static const int levelWarning = 3;
  static const int levelInformation = 4;
  static const int levelDebug = 5;

  static const int levelDefault = levelOut;

  static const levels = [ 'quiet', 'errors', 'normal', 'warnings', 'info', 'debug' ];

  static final RegExp rexPrefix = RegExp(r'^', multiLine: true);

  String _format = formatDefault;
  String get format => _format;
  set format(String? value) => _format = (value ?? formatDefault);

  int _level = levelDefault;
  int get level => _level;

  set level(int value) =>
    _level = value < 0 ? levelDefault :
             value >= levelDebug ? levelDebug : value;

  set levelAsString(String value) {
    if (value.isBlank()) {
      _level = levelDefault;
    }
    else {
      var i = levels.indexOf(value);
      level = (i >= 0 ? i : int.tryParse(value) ?? levelDefault);
    }
  }

  Logger([int? newLevel]) {
    level = newLevel ?? levelDefault;
  }

  String? debug(String data) =>
    print(data, levelDebug);

  String? error(String data) =>
    print(data, levelError);

  String? formatMessage(String msg, int level) {
    if ((level > _level) || (level < -_level) ||
        (level == levelSilent) || (_level == levelSilent)) {
      return null;
    }

    if (level == levelOut) {
      return msg;
    }

    var now = DateTime.now().toString();
    var lvl = levelToString(level);
    var pfx = (_format.isEmpty ? _format : _format.replaceFirst(stubTime, now).replaceFirst(stubLevel, lvl).replaceFirst(stubMessage, msg));

    var msgEx = msg.replaceAll(rexPrefix, pfx);

    return msgEx;
  }

  IOSink getSink(int level) =>
      (level == levelOut ? stdout : stderr);

  bool hasMinLevel(int minLevel) => (_level >= minLevel);

  bool get hasLevel => (_level != levelDefault);

  bool get isDebug => (_level >= levelDebug);

  bool get isInfo => (_level >= levelInformation);

  bool get isSilent => (_level == levelSilent);

  bool get isUnknown => !hasLevel;

  String? information(String data) =>
    print(data, levelInformation);

  static String levelToString(int level) {
    switch (level) {
      case levelDebug: return 'DBG';
      case levelError: return 'ERR';
      case levelInformation: return 'INF';
      case levelWarning: return 'WRN';
      default: return '';
    }
  }

  String? out(String data) =>
    print(data, levelOut);

  String? outInfo(String data) =>
    print(data, -levelOut);

  String? print(String msg, int level) {
    var msgEx = formatMessage(msg, level);

    if (msgEx != null) {
      getSink(level).writeln(msgEx);
    }

    return msgEx;
  }

  String? warning(String data) =>
    print(data, levelWarning);
}