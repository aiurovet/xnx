import 'package:meta/meta.dart';
import 'package:thin_logger/thin_logger.dart';
import 'package:xnx/ext/string.dart';
import 'package:xnx/flat_map.dart';
import 'package:xnx/keywords.dart';
import 'package:xnx/operation.dart';

class Expression {
  static final RegExp rexEndsWithTrue = RegExp(
    r'(^|[\s\(\|])(true|[1-9][0-9]*)[\s\)[\|]*$',
  );
  static final RegExp rexEndsWithFalse =
      RegExp(r'(^|[\s\(\&])(false|[0]+)[\s\)[\&]*$');

  @protected
  final FlatMap flatMap;
  @protected
  final Keywords keywords;
  @protected
  final Logger logger;
  @protected
  final Operation operation;

  Expression(
      {required this.flatMap,
      required this.keywords,
      required this.operation,
      required this.logger});

  Object? exec(Map<String, Object?> mapIf) {
    var firstEntry = mapIf.entries.first;
    var condition = firstEntry.key;
    var blockThen = firstEntry.value;
    var blockElse = mapIf[keywords.forElse];

    if (condition.isEmpty) {
      return blockElse;
    }

    var isThen = _exec(condition);

    if (logger.isVerbose) {
      logger
          .verbose('Condition: $condition\n...${isThen ? 'true' : 'false'}\n');
    }

    return (isThen ? blockThen : blockElse);
  }

  bool _exec(String condition) {
    if (condition.isBlank()) {
      return false;
    }

    for (;;) {
      var chunk = _getFirstChunk(condition);
      var start = chunk[0];
      var end = chunk[1];

      if (start < 0) {
        break;
      }

      var before = condition.substring(0, start);

      if (rexEndsWithFalse.hasMatch(before)) {
        return false;
      }

      if (rexEndsWithTrue.hasMatch(before)) {
        return true;
      }

      var result = _exec(condition.substring(start + 1, end - 1));
      condition = condition.replaceRange(start, end, (result ? '1' : '0'));
    }

    return _execBracketFree(condition.trim());
  }

  bool _execBracketFree(String condition) {
    var orParts = condition.split('||');

    for (var orPart in orParts) {
      var andParts = orPart.split('&&');
      var isThen = true;

      for (var andPart in andParts) {
        if (!operation.exec(andPart.trim())) {
          isThen = false;
          break;
        }
      }

      if (isThen) {
        return true;
      }
    }

    return false;
  }

  List<int> _getFirstChunk(String condition) {
    var beg = -1;
    var bracketCount = 0;
    var len = condition.length;
    var isEscaped = false;
    var isQuoted = false;
    var quote = '';

    for (var curPos = 0; curPos < len; curPos++) {
      var curChar = condition[curPos];

      if (curChar == r'\') {
        if (isQuoted) {
          isEscaped = !isEscaped;
        }
        continue;
      }

      switch (curChar) {
        case StringExt.apos:
        case StringExt.quot:
          if (!isEscaped) {
            if (isQuoted) {
              if (curChar == quote) {
                quote = '';
                isQuoted = false;
              }
            } else {
              quote = curChar;
              isQuoted = true;
            }
          }
          break;
        case '(':
          if (!isQuoted) {
            ++bracketCount;
            if (beg < 0) {
              beg = curPos;
            }
          }
          break;
        case ')':
          if (!isQuoted) {
            --bracketCount;
            if (bracketCount == 0) {
              return [beg, curPos + 1];
            }
          }
          break;
        default:
          break;
      }

      isEscaped = false;
    }

    if (bracketCount > 0) {
      throw Exception('Too many opening parentheses in $condition');
    }

    if (bracketCount < 0) {
      throw Exception('Too many closing parentheses in $condition');
    }

    return [-1, -1];
  }
}
