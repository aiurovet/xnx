import 'package:file/file.dart';
import 'package:meta/meta.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';

import 'flat_map.dart';

enum OperationType {
  unknown,
  alwaysFalse,
  alwaysTrue,
  equals,
  exists,
  existsDir,
  existsFile,
  fileEquals,
  fileNewer,
  fileNotEquals,
  fileOlder,
  greater,
  greaterOrEquals,
  less,
  lessOrEquals,
  matches,
  notEquals,
  notExists,
  notExistsDir,
  notExistsFile,
  notMatches,
}

class Operation {

  //////////////////////////////////////////////////////////////////////////////
  // Straight -> opposite operation type mapping
  //////////////////////////////////////////////////////////////////////////////

  static const Map<OperationType, OperationType> _oppositeOf = {
    OperationType.unknown: OperationType.unknown,
    OperationType.alwaysFalse: OperationType.alwaysTrue,
    OperationType.alwaysTrue: OperationType.alwaysFalse,
    OperationType.equals: OperationType.notEquals,
    OperationType.exists: OperationType.notExists,
    OperationType.existsDir: OperationType.notExistsDir,
    OperationType.existsFile: OperationType.notExistsFile,
    OperationType.fileEquals: OperationType.fileNotEquals,
    OperationType.fileNewer: OperationType.fileOlder,
    OperationType.fileNotEquals: OperationType.fileEquals,
    OperationType.fileOlder: OperationType.fileNewer,
    OperationType.greater: OperationType.lessOrEquals,
    OperationType.greaterOrEquals: OperationType.less,
    OperationType.less: OperationType.greaterOrEquals,
    OperationType.lessOrEquals: OperationType.greater,
    OperationType.matches: OperationType.notMatches,
    OperationType.notEquals: OperationType.equals,
    OperationType.notExists: OperationType.exists,
    OperationType.notExistsDir: OperationType.existsDir,
    OperationType.notExistsFile: OperationType.existsFile,
    OperationType.notMatches: OperationType.matches,
  };

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  OperationType type = OperationType.unknown;

  bool isCaseSensitive = true;
  bool isDotAll = false;
  bool isMultiLine = false;
  bool isUnicode = false;

  List<Object?> operands = [];

  //////////////////////////////////////////////////////////////////////////////
  // Private members
  //////////////////////////////////////////////////////////////////////////////

  @protected final FlatMap flatMap;
  @protected final Logger logger;
  @protected final RegExp rexQuoted = RegExp('^(".*"|\'.*\')\$');

  var _condition = '';
  var _isOpposite = false;
  var _begPos = -1;
  var _endPos = 0;

  //////////////////////////////////////////////////////////////////////////////

  Operation({required this.flatMap, required this.logger});

  //////////////////////////////////////////////////////////////////////////////

  bool exec(String condition) {
    switch (parse(condition)) {
      case OperationType.alwaysFalse:
        return false;
      case OperationType.alwaysTrue:
        return true;
      case OperationType.equals:
      case OperationType.greater:
      case OperationType.greaterOrEquals:
      case OperationType.less:
      case OperationType.lessOrEquals:
      case OperationType.notEquals:
        return _execCompare();
      case OperationType.fileEquals:
      case OperationType.fileNewer:
      case OperationType.fileNotEquals:
      case OperationType.fileOlder:
        return _execFileCompare();
      case OperationType.exists:
      case OperationType.existsDir:
      case OperationType.existsFile:
      case OperationType.notExists:
      case OperationType.notExistsDir:
      case OperationType.notExistsFile:
        return _execExists();
      case OperationType.matches:
      case OperationType.notMatches:
        return _execMatches();
      default:
        return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkCompares(int from, int length) {
    switch (_condition[from]) {
      case '<':
        type = OperationType.less;
        break;
      case '>':
        type = OperationType.greater;
        break;
      default:
        return false;
    }

    var last = from + 1;

    for (; last < length; last++) {
      switch (_condition[last]) {
        case '=':
          type = (type == OperationType.less ? OperationType.lessOrEquals :
          OperationType.greaterOrEquals);
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

    type = OperationType.equals;

    if (_begPos < 0) {
      _begPos = from;
    }

    _endPos = last;

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _checkFileOper(int from, int length) {
    var last = from + 1;
    var operEnd = last;

    if (last < length) {
      operEnd = _condition.indexOf(' ', last);

      if (operEnd < 0) {
        operEnd = length;
      }

      switch (_condition.substring(last, operEnd)) {
        case 'd':
          type = OperationType.existsDir;
          break;
        case 'e':
          type = OperationType.exists;
          break;
        case 'f':
          type = OperationType.existsFile;
          break;
        case 'feq':
          type = OperationType.fileEquals;
          break;
        case 'fne':
          type = OperationType.fileNotEquals;
          break;
        case 'fnw':
          type = OperationType.fileNewer;
          break;
        case 'fol':
          type = OperationType.fileOlder;
          break;
        default:
          return false;
      }
    }

    if (_begPos < 0) {
      _begPos = from;
    }

    _endPos = operEnd;

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

    type = OperationType.matches;

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
      type = OperationType.alwaysFalse;
      return true;
    }

    var from = _skipNegations(0, length) + 1;
    var conditionLC = _condition.substring(from).toLowerCase();

    if ((from >= length) || (conditionLC == 'false')) {
      type = OperationType.alwaysFalse;
    }
    else {
      var n = num.tryParse(conditionLC);

      if ((n ?? -1) == 0) {
        type = OperationType.alwaysFalse;
      }
      else {
        if (conditionLC == 'true') {
          type = OperationType.alwaysTrue;
        }
        else {
          if ((n != null) && (n != 0)){
            type = OperationType.alwaysTrue;
          }
        }
      }
    }

    if (type == OperationType.unknown) {
      return false;
    }

    if (_isOpposite) {
      if (type == OperationType.alwaysFalse) {
        type = OperationType.alwaysTrue;
      }
      else {
        type = OperationType.alwaysFalse;
      }
      _isOpposite = false;
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execCompare() {
    var o1 = _expandString(operands[0]);
    var o2 = _expandString(operands[1]);

    var n1 = num.tryParse(o1);
    var n2 = num.tryParse(o2);

    var cmpResult = 0;

    if ((n1 != null) && (n2 != null)) {
      cmpResult = (n1 < n2 ? -1 : (n1 > n2 ? 1 : 0));
    }
    else {
      cmpResult = (isCaseSensitive ? o1 : o1.toLowerCase()).compareTo(isCaseSensitive ? o2 : o2.toLowerCase());
    }

    var isThen = (
      type == OperationType.less ? (cmpResult <  0) :
      type == OperationType.lessOrEquals ? (cmpResult <= 0) :
      type == OperationType.greaterOrEquals ? (cmpResult >= 0) :
      type == OperationType.greater ? (cmpResult >  0) :
      type == OperationType.equals ? (cmpResult == 0) :
      type == OperationType.notEquals ? (cmpResult != 0) :
      false
    );

    if (logger.isDebug) {
      logger.debug('$type\n...op1: $o1\n...op2: $o2\n...${isThen ? 'true' : 'false'}\n');
    }

    return isThen;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execFileCompare() {
    var path1 = _expandString(operands[0], canUnquote: true);
    var path2 = _expandString(operands[1], canUnquote: true);

    var stat1 = _getStat(path1);
    var stat2 = _getStat(path2);

    var isFound1 = (stat1.type != FileSystemEntityType.notFound);
    var isFound2 = (stat2.type != FileSystemEntityType.notFound);

    if (isFound1 && isFound2 && (stat1.type != stat2.type)) {
      _fail('Failed to compare ${stat1.type} $path1 to ${stat2.type} $path2');
    }

    var time1 = (isFound1 ? stat1.modified.millisecondsSinceEpoch : -1);
    var time2 = (isFound2 ? stat2.modified.millisecondsSinceEpoch : -1);
    var isThen = false;

    switch (type) {
      case OperationType.fileEquals:
        isThen = (time1 == time2);
        break;
      case OperationType.fileNewer:
        isThen = (time1 > time2);
        break;
      case OperationType.fileNotEquals:
        isThen = (time1 != time2);
        break;
      case OperationType.fileOlder:
        isThen = (time1 < time2);
        break;
      default:
        break;
    }

    if (logger.isDebug) {
      logger.debug('$type\n...path1: $path1\n...path2: $path2\n...${isThen ? 'true' : 'false'}\n');
    }

    return isThen;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execExists() {
    var mask = _expandString(operands[0], canUnquote: true);

    var isThen = true;

    if (mask.isNotEmpty) {
      isThen = (mask.isEmpty ? false : FileSystemEntityExt.tryPatternExistsSync(
        mask,
        isDirectory: (type == OperationType.existsDir),
        isFile: (type == OperationType.existsFile),
      ));
    }

    if ((type == OperationType.notExists) ||
        (type == OperationType.notExistsDir) ||
        (type == OperationType.notExistsFile)) {
      return !isThen;
    }

    if (logger.isDebug) {
      logger.debug('$type\n...mask: $mask\n...${isThen ? 'true' : 'false'}\n');
    }

    return isThen;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _execMatches() {
    var inp = _expandString(operands[0]);
    var pat = _expandString(operands[1]);

    if (inp.isNotEmpty && pat.isNotEmpty) {
      if (rexQuoted.hasMatch(inp)) {
        if (pat.isNotEmpty && pat.isNotEmpty) {
          if (rexQuoted.hasMatch(pat)) {
            inp = inp.substring(1, inp.length - 1);
            pat = pat.substring(1, pat.length - 1);
          }
        }
      }
    }

    var isThen = (pat.isEmpty ? false : RegExp(
      pat,
      caseSensitive: isCaseSensitive,
      dotAll: isDotAll,
      multiLine: isMultiLine,
      unicode: isUnicode
    ).hasMatch(inp));


    if (logger.isDebug) {
      logger.debug('$type\n...input:   "$inp"\n...pattern: "$pat"\n...${isThen ? 'true' : 'false'}\n');
    }

    return (type == OperationType.notMatches ? !isThen : isThen);
  }

  //////////////////////////////////////////////////////////////////////////////

  String _expandString(Object? input, {bool canUnquote = false}) {
    var result = flatMap.expand(input?.toString());

    if (canUnquote) {
      result = result.unquote();
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  Never _fail(String condition, [String? details]) =>
    throw Exception('Invalid condition $condition${details?.isNotEmpty ?? false ? ': $details' : ''}');

  //////////////////////////////////////////////////////////////////////////////

  FileStat _getStat(String path) {
    var file = Path.fileSystem.file(path);
    var stat = file.statSync();

    if (stat.type == FileSystemEntityType.link) {
      stat = _getStat(file.resolveSymbolicLinksSync());
    }

    return stat;
  }

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
          isFound = _checkFileOper(curPos, length);
          continue;
        case ' ':
        case '\t':
          isFound = (type != OperationType.unknown);
          continue;
      }
    }

    if (type == OperationType.unknown) {
      var isEmpty = _condition.replaceAll('!', '').isBlank();
      type = (isEmpty ? OperationType.alwaysFalse : OperationType.alwaysTrue);
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

    type = OperationType.unknown;

    isCaseSensitive = true;
    isDotAll = false;
    isMultiLine = false;
    isUnicode = false;

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  void _setOperands() {
    if ((type == OperationType.alwaysTrue) ||
        (type == OperationType.alwaysFalse)) {
      return;
    }

    if ((_begPos < 0) || (_endPos <= _begPos)) {
      _fail(_condition);
    }

    var isBinary = (
      (type == OperationType.fileEquals) ||
      (type == OperationType.fileNewer) ||
      (type == OperationType.fileNotEquals) ||
      (type == OperationType.fileOlder) ||
      (type == OperationType.equals) ||
      (type == OperationType.greater) ||
      (type == OperationType.greaterOrEquals) ||
      (type == OperationType.less) ||
      (type == OperationType.lessOrEquals) ||
      (type == OperationType.equals) ||
      (type == OperationType.matches) ||
      (type == OperationType.notEquals) ||
      (type == OperationType.notMatches)
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

    if (type == OperationType.unknown) {
      if (((n1 != null) && (n1 == 0)) || (o1?.isEmpty ?? true)) {
        if (_isOpposite) {
          type = OperationType.alwaysTrue;
        }
        else {
          type = OperationType.alwaysFalse;
        }
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int _skipNegations(int from, int length) {
    if (from <= 0) {
      _isOpposite = false;
    }

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