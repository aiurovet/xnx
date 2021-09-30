import 'dart:io';

import 'package:test/test.dart';
import 'package:xnx/src/logger.dart';

void main() {
  group('Logger', () {
    test('level', () {
      var logger = Logger();

      logger.level = Logger.LEVEL_SILENT - 1;
      expect(logger.level, Logger.LEVEL_DEFAULT);

      for (var level = Logger.LEVEL_SILENT; level < Logger.LEVEL_DEBUG; level++) {
        logger.level = level;
        expect(logger.level, level);
      }

      logger.level = Logger.LEVEL_DEBUG + 1;
      expect(logger.level, Logger.LEVEL_DEBUG);
    });

    test('levelAsString', () {
      var logger = Logger();

      logger.levelAsString = '';
      expect(logger.level, Logger.LEVEL_DEFAULT);

      logger.levelAsString = '-1';
      expect(logger.level, Logger.LEVEL_DEFAULT);

      var level = -1;

      for (var levelAsString in Logger.LEVELS) {
        ++level;
        logger.levelAsString = levelAsString;
        expect(logger.level, level);
      }
    });

    test('formatMessage', () {
      var logger = Logger(Logger.LEVEL_SILENT);
      var text = 'Abc';
      expect(logger.formatMessage(text, Logger.LEVEL_SILENT - 1), null);
      expect(logger.formatMessage(text, Logger.LEVEL_SILENT - 0), null);
      expect(logger.formatMessage(text, Logger.LEVEL_SILENT + 1), null);

      for (var level = Logger.LEVEL_ERROR; level <= Logger.LEVEL_DEBUG; level++) {
        logger.level = level;
        expect(logger.formatMessage(text, level - 1), ((level - 1 == Logger.LEVEL_SILENT) || (level - 1 > logger.level) ? null : text));
        expect(logger.formatMessage(text, level - 0), ((level - 0 == Logger.LEVEL_SILENT) || (level - 0 > logger.level) ? null : text));
        expect(logger.formatMessage(text, level + 1), ((level + 1 == Logger.LEVEL_SILENT) || (level + 1 > logger.level) ? null : text));
      }
    });

    test('getSink', () {
      var logger = Logger();

      for (var level = Logger.LEVEL_SILENT; level <= Logger.LEVEL_DEBUG; level++) {
        expect(logger.getSink(level), (level == Logger.LEVEL_OUT ? stdout : stderr));
      }
    });
  });
}
