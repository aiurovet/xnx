import 'dart:io';

import 'package:test/test.dart';
import 'package:xnx/src/logger.dart';

void main() {
  group('Logger', () {
    test('level', () {
      var logger = Logger();

      logger.level = Logger.levelSilent - 1;
      expect(logger.level, Logger.levelDefault);

      for (var level = Logger.levelSilent; level < Logger.levelDebug; level++) {
        logger.level = level;
        expect(logger.level, level);
      }

      logger.level = Logger.levelDebug + 1;
      expect(logger.level, Logger.levelDebug);
    });

    test('levelAsString', () {
      var logger = Logger();

      logger.levelAsString = '';
      expect(logger.level, Logger.levelDefault);

      logger.levelAsString = '-1';
      expect(logger.level, Logger.levelDefault);

      var level = -1;

      for (var levelAsString in Logger.levels) {
        ++level;
        logger.levelAsString = levelAsString;
        expect(logger.level, level);
      }
    });

    test('formatMessage', () {
      var logger = Logger(Logger.levelSilent);
      var text = 'Abc';
      expect(logger.formatMessage(text, Logger.levelSilent - 1), null);
      expect(logger.formatMessage(text, Logger.levelSilent - 0), null);
      expect(logger.formatMessage(text, Logger.levelSilent + 1), null);

      for (var level = Logger.levelError; level <= Logger.levelDebug; level++) {
        logger.level = level;
        expect(logger.formatMessage(text, level - 1), ((level - 1 == Logger.levelSilent) || (level - 1 > logger.level) ? null : text));
        expect(logger.formatMessage(text, level - 0), ((level - 0 == Logger.levelSilent) || (level - 0 > logger.level) ? null : text));
        expect(logger.formatMessage(text, level + 1), ((level + 1 == Logger.levelSilent) || (level + 1 > logger.level) ? null : text));
      }
    });

    test('getSink', () {
      var logger = Logger();

      for (var level = Logger.levelSilent; level <= Logger.levelDebug; level++) {
        expect(logger.getSink(level), (level == Logger.levelOut ? stdout : stderr));
      }
    });
  });
}
