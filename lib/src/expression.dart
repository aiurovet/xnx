import 'package:xnx/src/config.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/ext/string.dart';

class Expression {
  static RegExp RE_ENDS_WITH_TRUE = RegExp(r'(^|[\s\(\|])(true|[1-9][0-9]*)[\s\)[\|]*$',);
  static RegExp RE_ENDS_WITH_FALSE = RegExp(r'(^|[\s\(\&])(false|[0]+)[\s\)[\&]*$');

  final Config _config;

  Expression(this._config);

  Object exec(Map<String, Object> mapIf) {
    var condition = mapIf?.entries?.firstWhere((x) =>
      (x.key != _config.condNameThen) &&
      (x.key != _config.condNameElse),
      orElse: () => null
    )?.value;

    if (condition == null) {
      throw Exception('Condition not found in "$mapIf"');
    }

    var blockThen = mapIf[_config.condNameThen];

    if (blockThen == null) {
      throw Exception('Then-block not found in "$mapIf"');
    }

    var isThen = _exec(condition);

    return (isThen ? blockThen : mapIf[_config.condNameElse]);
  }

  bool _exec(String condition) {
    if (StringExt.isNullOrBlank(condition)) {
      return null;
    }

    for (; ;) {
      var chunk = _getFirstChunk(condition);
      var start = chunk[0];
      var end = chunk[1];

      if (start < 0) {
        break;
      }

      var before = condition.substring(0, start);

      if (RE_ENDS_WITH_FALSE.hasMatch(before)) {
        return false;
      }

      if (RE_ENDS_WITH_TRUE.hasMatch(before)) {
        return true;
      }

      var result = _exec(condition.substring(start + 1, end - 1));
      condition = condition.replaceRange(start, end, (result ? '1' : '0'));
    }

    return _execBracketFree(condition.trim());
  }

  bool _execBondFree(String condition) {
    List<Object> x;

    var conditionLower = condition.toLowerCase();
    var conditionAsNum = int.tryParse(conditionLower);

    if ((conditionLower == 'true') || ((conditionAsNum != null) && (conditionAsNum != 0))) {
      return true;
    }
    if ((conditionLower == 'false') || ((conditionAsNum != null) && (conditionAsNum == 0))) {
      return false;
    }
    if ((x = _parseOper(condition, '!-d', 1)) != null) {
      return _execOperExists(x[0], isStraight: false, isDir: true);
    }
    if ((x = _parseOper(condition, '-d', 1)) != null) {
      return _execOperExists(x[0], isStraight: false, isDir: true);
    }
    if ((x = _parseOper(condition, '!-e', 1)) != null) {
      return _execOperExists(x[0], isStraight: false);
    }
    if ((x = _parseOper(condition, '-e', 1)) != null) {
      return _execOperExists(x[0], isStraight: true);
    }
    if ((x = _parseOper(condition, '!-f', 1)) != null) {
      return _execOperExists(x[0], isStraight: false, isDir: false);
    }
    if ((x = _parseOper(condition, '-f', 1)) != null) {
      return _execOperExists(x[0], isStraight: true, isDir: false);
    }
    if ((x = _parseOper(condition, '!=/i', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: false, isCase: false, cmpType: 0);
    }
    if ((x = _parseOper(condition, '!=', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: false, isCase: true, cmpType: 0);
    }
    if ((x = _parseOper(condition, '==/i', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: true, isCase: false, cmpType: 0);
    }
    if ((x = _parseOper(condition, '==', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: true, isCase: true, cmpType: 0);
    }
    if ((x = _parseOper(condition, '!~/i', 2, canBeNum: true)) != null) {
      return _execOperMatch(x[0], x[1], isStraight: false, isCase: false);
    }
    if ((x = _parseOper(condition, '!~', 2, canBeNum: true)) != null) {
      return _execOperMatch(x[0], x[1], isStraight: false, isCase: true);
    }
    if ((x = _parseOper(condition, '~/i', 2, canBeNum: true)) != null) {
      return _execOperMatch(x[0], x[1], isStraight: true, isCase: false);
    }
    if ((x = _parseOper(condition, '~', 2, canBeNum: true)) != null) {
      return _execOperMatch(x[0], x[1], isStraight: true, isCase: true);
    }
    if ((x = _parseOper(condition, '>=', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: false, isCase: true, cmpType: 1);
    }
    if ((x = _parseOper(condition, '>', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: false, isCase: true, cmpType: 2);
    }
    if ((x = _parseOper(condition, '<=', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: false, isCase: true, cmpType: -1);
    }
    if ((x = _parseOper(condition, '<', 2, canBeNum: true)) != null) {
      return _execOperCompare(x[0], x[1], isStraight: false, isCase: true, cmpType: -2);
    }

    return false;
  }

  bool _execBracketFree(String condition) {
    var orParts = condition.split('||');

    for (var orPart in orParts) {
      var andParts = orPart.split('&&');
      var isThen = true;

      for (var andPart in andParts) {
        if (!_execBondFree(andPart.trim())) {
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

  bool _execOperCompare(Object o1, Object o2, {bool isStraight, bool isCase, int cmpType}) {
    cmpType ??= 0;

    var cmpResult = -cmpType;

    if ((o1 is num) && (o2 is num)) {
      cmpResult = (o1 - o2);
    }
    else if ((o1 is String) && (o2 is String)) {
      cmpResult = (isCase ? o1 : o1.toLowerCase()).compareTo(isCase ? o2 : o2.toLowerCase());
    }

    var isThen = (
      cmpType <  -1 ? (cmpResult <  0) :
      cmpType == -1 ? (cmpResult <= 0) :
      cmpType ==  1 ? (cmpResult >= 0) :
      cmpType >   1 ? (cmpResult >  0) :
                      (cmpResult == 0)
    );

    return (isThen == isStraight);
  }

  bool _execOperExists(String mask, {bool isStraight, bool isDir}) {
    var maskEx = _config.expandStraight(_config.flatMap, mask).unquote();
    var isThen = FileSystemEntityExt.tryPatternExistsSync(maskEx, isDirectory: isDir, isFile: (isDir == null ? null : !isDir));

    return (isThen && isStraight);
  }

  bool _execOperMatch(Object o1, Object o2, {bool isStraight, bool isCase}) {
    var isThen = RegExp(o2, caseSensitive: isCase).hasMatch(o1);

    return (isThen && isStraight);
  }

  List<int> _getFirstChunk(String condition) {
    var beg = -1;
    var len = condition.length;
    var bracketCount = 0;

    for (var cur = 0; cur < len; cur++) {
      switch (condition[cur]) {
        case '(':
          ++bracketCount;
          if (beg < 0) {
            beg = cur;
          }
          break;
        case ')':
          --bracketCount;
          if (bracketCount == 0) {
            return [beg, cur + 1];
          }
          break;
      }
    }

    if (bracketCount > 0) {
      throw Exception('Too many opening parentheses in $condition');
    }

    if (bracketCount < 0) {
      throw Exception('Too many closing parentheses in $condition');
    }

    return [-1, -1];
  }

  List<Object> _parseOper(String condition, String operName, int count, {bool canBeNum = false}) {
    var beg = condition.indexOf(operName);

    if (beg < 0) {
      return null;
    }

    var flatMap = _config.flatMap;

    if (count == 1) {
      if (beg > 0) {
        throw Exception('Condition $condition has unary operation which should appear in the front');
      }

      var o1 = _config.expandStraight(flatMap, condition.substring(operName.length).trim());
      var n1 = ((canBeNum ?? false) ? num.tryParse(o1) : null);

      if ((canBeNum ?? false) && (n1 == null)) {
        throw Exception('The operand of $condition should be numeric');
      }

      return [(n1 ?? o1)];
    }
    else if (count == 2) {
      var o1 = _config.expandStraight(flatMap, condition.substring(0, beg).trim());
      var o2 = _config.expandStraight(flatMap, condition.substring(beg + operName.length).trim());

      var n1 = ((canBeNum ?? false) ? num.tryParse(o1) : null);
      var n2 = ((canBeNum ?? false) ? num.tryParse(o2) : null);

      var isNum = ((n1 != null) && (n2 != null));

      return [(isNum ? n1 : o1), (isNum ? n2 : o2)];
    }
    else {
      throw Exception('Operations with more than two operands are not supported');
    }
  }
}