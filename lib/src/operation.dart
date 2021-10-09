import 'package:meta/meta.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/ext/string.dart';

import 'flat_map.dart';

enum OperationType {
  Unknown,
  AlwaysFalse,
  AlwaysTrue,
  Equals,
  Exists,
  ExistsDir,
  ExistsFile,
  Greater,
  GreaterOrEquals,
  Less,
  LessOrEquals,
  Matches,
  NotEquals,
  NotExists,
  NotExistsDir,
  NotExistsFile,
  NotMatches,
}

class Operation {

  //////////////////////////////////////////////////////////////////////////////
  // Straight -> opposite operation type mapping
  //////////////////////////////////////////////////////////////////////////////

  static const Map<OperationType, OperationType> _oppositeOf = {
    OperationType.Unknown: OperationType.Unknown,
    OperationType.AlwaysFalse: OperationType.AlwaysTrue,
    OperationType.AlwaysTrue: OperationType.AlwaysFalse,
    OperationType.Equals: OperationType.NotEquals,
    OperationType.Exists: OperationType.NotExists,
    OperationType.ExistsDir: OperationType.NotExistsDir,
    OperationType.ExistsFile: OperationType.NotExistsFile,
    OperationType.Greater: OperationType.LessOrEquals,
    OperationType.GreaterOrEquals: OperationType.Less,
    OperationType.Less: OperationType.GreaterOrEquals,
    OperationType.LessOrEquals: OperationType.Greater,
    OperationType.Matches: OperationType.NotMatches,
    OperationType.NotEquals: OperationType.Equals,
    OperationType.NotExists: OperationType.Exists,
    OperationType.NotExistsDir: OperationType.ExistsDir,
    OperationType.NotExistsFile: OperationType.ExistsFile,
    OperationType.NotMatches: OperationType.Matches,
  };

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  OperationType type = OperationType.Unknown;

  bool isCaseSensitive = true;
  bool isDotAll = false;
  bool isMultiLine = false;
  bool isUnicode = false;

  List<Object?> operands = [];

  //////////////////////////////////////////////////////////////////////////////
  // Private members
  //////////////////////////////////////////////////////////////////////////////

  @protected final FlatMap flatMap;

  var _condition = '';
  var _isOpposite = false;
  var _begPos = -1;
  var _endPos = 0;

  //////////////////////////////////////////////////////////////////////////////

  Operation({required this.flatMap});

  //////////////////////////////////////////////////////////////////////////////

  bool exec(String condition) {
    switch (parse(condition)) {
      case OperationType.AlwaysFalse:
        return false;
      case OperationType.AlwaysTrue:
        return true;
      case OperationType.Equals:
      case OperationType.Greater:
      case OperationType.GreaterOrEquals:
      case OperationType.Less:
      case OperationType.LessOrEquals:
      case OperationType.NotEquals:
        return _execCompare();
      case OperationType.Exists:
      case OperationType.ExistsDir:
      case OperationType.ExistsFile:
      case OperationType.NotExists:
      case OperationType.NotExistsDir:
      case OperationType.NotExistsFile:
        return _execExists();
      case OperationType.Matches:
      case OperationType.NotMatches:
        return _execMatches();
      default:
        return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkCompares(int from, int length) {
    switch (_condition[from]) {
      case '<':
        type = OperationType.Less;
        break;
      case '>':
        type = OperationType.Greater;
        break;
      default:
        return false;
    }

    var last = from + 1;

    for (; last < length; last++) {
      switch (_condition[last]) {
        case '=':
          type = (type == OperationType.Less ? OperationType.LessOrEquals :
          OperationType.GreaterOrEquals);
          continue;
        default:
          break;
      }
      break;
    }

    if (_begPos < 0) {
      _begPos = from;
    }

    _endPos = last;

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkEquals(int from, int length) {
    var last = from + 1;

    for (; last < length; last++) {
      switch (_condition[last]) {
        case '=':
          continue;
        case '/':
          if (((++last) < length) && (_condition[last] == 'i')) {
            ++last;
            isCaseSensitive = false;
          }
          break;
        default:
          break;
      }
      break;
    }

    type = OperationType.Equals;

    if (_begPos < 0) {
      _begPos = from;
    }

    _endPos = last;

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkExists(int from, int length) {
    var last = from + 1;

    if (last < length) {
      switch (_condition[last]) {
        case 'd':
          type = OperationType.ExistsDir;
          break;
        case 'e':
          type = OperationType.Exists;
          break;
        case 'f':
          type = OperationType.ExistsFile;
          break;
        default:
          return false;
      }
    }

    if (_begPos < 0) {
      _begPos = from;
    }

    _endPos = last + 1;

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkMatches(int from, int length) {
    var last = from + 1;

    if ((last < length) && (_condition[last] == '/')) {
      for (; (++last) < length;) {
        switch (_condition[last]) {
          case 'i':
            isCaseSensitive = false;
            continue;
          case 's':
            isDotAll = true;
            continue;
          case 'm':
            isMultiLine = true;
            continue;
          case 'u':
            isUnicode = true;
            continue;
          default:
            break;
        }
        break;
      }
    }

    type = OperationType.Matches;

    if (_begPos < 0) {
      _begPos = from;
    }

    _endPos = last;

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkTrueFalse() {
    var length = _condition.length;

    if (length <= 0) {
      type = OperationType.AlwaysFalse;
      return true;
    }

    var from = _skipNegations(0, length) + 1;
    var conditionLC = _condition.substring(from).toLowerCase();

    if ((from >= length) || (conditionLC == 'false')) {
      type = OperationType.AlwaysFalse;
    }
    else {
      var n = num.tryParse(conditionLC);

      if ((n ?? -1) == 0) {
        type = OperationType.AlwaysFalse;
      }
      else {
        if (conditionLC == 'true') {
          type = OperationType.AlwaysTrue;
        }
        else {
          if ((n != null) && (n != 0)){
            type = OperationType.AlwaysTrue;
          }
        }
      }
    }

    if (_isOpposite) {
      if (type == OperationType.AlwaysFalse) {
        type = OperationType.AlwaysTrue;
      }
      else {
        type = OperationType.AlwaysFalse;
      }
      _isOpposite = false;
    }

    return (type != OperationType.Unknown);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execCompare() {
    var o1 = operands[0];
    var o2 = operands[1];

    var cmpResult = 0;

    if ((o1 is num) && (o2 is num)) {
      cmpResult = ((o1 - o2) as int);
    }
    else if ((o1 is String) && (o2 is String)) {
      cmpResult = (isCaseSensitive ? o1 : o1.toLowerCase()).compareTo(isCaseSensitive ? o2 : o2.toLowerCase());
    }

    var isThen = (
      type == OperationType.Less ? (cmpResult <  0) :
      type == OperationType.LessOrEquals ? (cmpResult <= 0) :
      type == OperationType.GreaterOrEquals ? (cmpResult >= 0) :
      type == OperationType.Greater ? (cmpResult >  0) :
      type == OperationType.Equals ? (cmpResult == 0) :
      type == OperationType.NotEquals ? (cmpResult != 0) :
      false
    );

    return isThen;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execExists() {
    var mask = (operands[0] as String);

    var isThen = true;

    if (mask.isNotEmpty) {
      mask = flatMap.expand(mask);

      isThen = (mask.isEmpty ? false : FileSystemEntityExt.tryPatternExistsSync(
        mask,
        isDirectory: (type == OperationType.ExistsDir),
        isFile: (type == OperationType.ExistsFile),
      ));
    }

    if ((type == OperationType.NotExists) ||
        (type == OperationType.NotExistsDir) ||
        (type == OperationType.NotExistsFile)) {
      return !isThen;
    }

    return isThen;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execMatches() {
    var pattern = (operands[1] as String);

    var isThen = (pattern.isEmpty ? false : RegExp(
      pattern,
      caseSensitive: isCaseSensitive,
      dotAll: isDotAll,
      multiLine: isMultiLine,
      unicode: isUnicode
    ).hasMatch(operands[0] as String));

    return (type == OperationType.NotMatches ? !isThen : isThen);
  }

  //////////////////////////////////////////////////////////////////////////////

  Never _fail(String condition, [String? details]) =>
    throw Exception('Invalid condition $condition${details?.isNotEmpty ?? false ? ': $details' : ''}');

  //////////////////////////////////////////////////////////////////////////////

  OperationType parse(String condition) {
    _reset(condition.trim());

    if (_checkTrueFalse()) {
      return type;
    }

    var curChr = '';
    var isQuote1 = false;
    var isQuote2 = false;
    var length = _condition.length;

    for (var isFound = false, curPos = 0; (curPos < length) && !isFound; curPos++) {
      curChr = _condition[curPos];

      switch (curChr) {
        case '"':
          _begPos = -1;
          if (!isQuote1) {
            isQuote2 = !isQuote2;
          }
          continue;
        case "'":
          _begPos = -1;
          if (!isQuote2) {
            isQuote1 = !isQuote1;
          }
          continue;
        default:
          if (isQuote1 || isQuote2) {
            continue;
          }
          break;
      }

      switch (curChr) {
        case '!':
          if (_begPos < 0) {
            _begPos = curPos;
          }
          curPos = _skipNegations(curPos, length);
          continue;
        case '~':
          isFound = _checkMatches(curPos, length);
          continue;
        case '=':
          isFound = _checkEquals(curPos, length);
          continue;
        case '<':
        case '>':
          isFound = _checkCompares(curPos, length);
          continue;
        case '-':
          isFound = _checkExists(curPos, length);
          continue;
        case ' ':
        case '\t':
          isFound = (type != OperationType.Unknown);
          continue;
      }
    }

    if (type == OperationType.Unknown) {
      var isEmpty = _condition.replaceAll('!', '').isBlank();
      type = (isEmpty ? OperationType.AlwaysFalse : OperationType.AlwaysTrue);
    }

    if (_isOpposite) {
      type = _oppositeOf[type] ?? type;
      _isOpposite = false;
    }

    _setOperands();

    return type;
  }

  //////////////////////////////////////////////////////////////////////////////

  Operation _reset([String? condition]) {
    if (condition != null) {
      _condition = condition;
    }

    _isOpposite = false;
    _begPos = -1;
    _endPos = 0;

    operands.clear();

    type = OperationType.Unknown;

    isCaseSensitive = true;
    isDotAll = false;
    isMultiLine = false;
    isUnicode = false;

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  void _setOperands() {
    if ((type == OperationType.AlwaysTrue) ||
        (type == OperationType.AlwaysFalse)) {
      return;
    }

    if ((_begPos < 0) || (_endPos <= _begPos)) {
      _fail(_condition);
    }

    var isBinary = (
      (type == OperationType.Equals) ||
      (type == OperationType.Greater) ||
      (type == OperationType.GreaterOrEquals) ||
      (type == OperationType.Less) ||
      (type == OperationType.LessOrEquals) ||
      (type == OperationType.Equals) ||
      (type == OperationType.Matches) ||
      (type == OperationType.NotEquals) ||
      (type == OperationType.NotMatches)
    );

    var expArgCount = (isBinary ? 2 : 1);
    var isUnary = (expArgCount == 1);

    if ((expArgCount <= 1) && (_begPos > 0)) {
      _fail(_condition, 'only one argument expected');
    }

    if ((expArgCount > 1) && (_begPos <= 0)) {
      _fail(_condition, 'two arguments expected');
    }

    var length = _condition.length;

    var begPos = (isUnary ? 0 : _begPos);
    var o1 = (isUnary ? null : (begPos >= 0 ? _condition.substring(0, begPos).trim() : _condition));
    var o2 = (begPos >= 0 ? _condition.substring(_endPos < length ? _endPos : length).trim() : null);

    num? n1;

    if (o1 != null) {
      o1 = flatMap.expand(o1);
      n1 = (isBinary ? num.tryParse(o1) : null);

      operands.add(n1 ?? o1);
    }

    num? n2;

    if (o2 != null) {
      o2 = flatMap.expand(o2);
      n2 = (isBinary && (n1 != null) ? num.tryParse(o2) : null);

      operands.add(n2 ?? o2);
    }

    if (type == OperationType.Unknown) {
      if (((n1 != null) && (n1 == 0)) || (o1?.isEmpty ?? true)) {
        if (_isOpposite) {
          type = OperationType.AlwaysTrue;
        }
        else {
          type = OperationType.AlwaysFalse;
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int _skipNegations(int from, int length) {
    var last = from;

    for (; last < length; last++) {
      var curChar = _condition[last];

      switch (curChar) {
        case '!':
          _isOpposite = !_isOpposite;
          continue;
        case ' ':
        case '\t':
          continue;
        default:
          break;
      }
      break;
    }

    return last - 1;
  }

  //////////////////////////////////////////////////////////////////////////////

}