import 'dart:math';

import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:xnx/src/command.dart';
import 'package:xnx/src/expression.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/operation.dart';

enum FunctionType {
  unknown,
  add,
  addDays,
  addMonths,
  addYears,
  baseName,
  baseNameNoExt,
  ceil,
  cos,
  date,
  dirName,
  div,
  divInt,
  endOfMonth,
  exp,
  extension,
  fileSize,
  floor,
  iif,
  indexOf,
  lastIndexOf,
  lastMatch,
  lastModified,
  match,
  len,
  ln,
  local,
  lower,
  max,
  min,
  mod,
  mul,
  now,
  pi,
  pow,
  rad,
  replace,
  replaceMatch,
  round,
  run,
  sin,
  sqrt,
  sub,
  substr,
  startOfMonth,
  tan,
  time,
  title,
  today,
  upper,
  utc,
}

class Functions {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final int defaultNumericPrecision = 6;
  static final RegExp _rexGroup = RegExp(r'(\\\\)|(\\\$)|(\$([\d]+))|\$\{([\d]+)\}');

  //////////////////////////////////////////////////////////////////////////////
  // Protected members
  //////////////////////////////////////////////////////////////////////////////

  @protected late final Expression expression;
  @protected final FlatMap flatMap;
  @protected final Keywords keywords;
  @protected final Logger logger;
  @protected late final Operation operation;
  @protected final Map<String, FunctionType> nameTypeMap = {};
  int numericPrecision = defaultNumericPrecision;

  //////////////////////////////////////////////////////////////////////////////

  Functions({required this.flatMap, required this.keywords, required this.logger, int? numericPrecision}) {
    if (numericPrecision != null) {
      this.numericPrecision = numericPrecision;
    }

    operation = Operation(flatMap: flatMap, logger: logger);
    expression = Expression(flatMap: flatMap, keywords: keywords, operation: operation, logger: logger);

    _initNameTypeMap();
  }

  //////////////////////////////////////////////////////////////////////////////

  Object? exec(Object? todo, {int offset = 0}) {
    if (todo is List) {
      if (todo.isNotEmpty) {
        var first = todo[0];

        if ((first is String)) {
          var type = nameTypeMap[_toName(first)];

          if ((type != null) && (type != FunctionType.unknown)) {
            return _exec(type, todo, offset: offset);
          }
        }
      }

      for (var x in todo) {
        exec(x);
      }
    }
    else if (todo is Map<String, Object?>) {
      todo.forEach((key, value) {
        var name = key.replaceAll(' ', '').toLowerCase();
        var type = nameTypeMap[name] ?? FunctionType.unknown;
        Object? newValue;

        if (type == FunctionType.unknown) {
          newValue = exec(value);
        }
        else if (value is List<Object?>) {
          newValue = _exec(type, value).toString();
        }
        else {
          _fail(type, 'invalid argument(s)');
        }

        if (newValue == null) {
          flatMap.remove(key);
        }
        else {
          flatMap[key] = newValue.toString();
        }
      });
    }
    else if (todo != null) {
      return flatMap.expand(todo.toString());
    }

    return todo;
  }

  //////////////////////////////////////////////////////////////////////////////

  void init(Map data) {
    var numericPrecisionStr = data[keywords.forNumericPrecision]?.toString();

    if (numericPrecisionStr != null) {
      numericPrecision = (num.tryParse(numericPrecisionStr)?.floor() ?? numericPrecision);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Object? _exec(FunctionType type, List<Object?> todo, {int offset = 0}) {
    switch (type) {
      case FunctionType.add:
      case FunctionType.ceil:
      case FunctionType.cos:
      case FunctionType.div:
      case FunctionType.divInt:
      case FunctionType.exp:
      case FunctionType.floor:
      case FunctionType.ln:
      case FunctionType.max:
      case FunctionType.min:
      case FunctionType.mod:
      case FunctionType.mul:
      case FunctionType.pi:
      case FunctionType.pow:
      case FunctionType.rad:
      case FunctionType.round:
      case FunctionType.sin:
      case FunctionType.sqrt:
      case FunctionType.sub:
      case FunctionType.tan:
        return _execMath(type, todo, offset: offset);
      case FunctionType.addDays:
      case FunctionType.addMonths:
      case FunctionType.addYears:
      case FunctionType.date:
      case FunctionType.endOfMonth:
      case FunctionType.local:
      case FunctionType.startOfMonth:
      case FunctionType.time:
      case FunctionType.utc:
        return _execDateTime(type, todo, offset: offset);
      case FunctionType.baseName:
      case FunctionType.baseNameNoExt:
      case FunctionType.dirName:
      case FunctionType.extension:
      case FunctionType.fileSize:
      case FunctionType.lastModified:
        return _execFile(type, todo, offset: offset);
      case FunctionType.iif:
        return _execIif(type, todo, offset: offset);
      case FunctionType.len:
        return _execLen(type, todo, offset: offset);
      case FunctionType.indexOf:
      case FunctionType.lastIndexOf:
        return _execIndex(type, todo, offset: offset);
      case FunctionType.lastMatch:
      case FunctionType.match:
        return _execMatch(type, todo, offset: offset);
      case FunctionType.run:
        return _execRun(type, todo, offset: offset);
      case FunctionType.now:
      case FunctionType.today:
        return _execDateTimeNow(type, todo, offset: offset);
      case FunctionType.replace:
        return _execReplace(type, todo, offset: offset);
      case FunctionType.replaceMatch:
        return _execReplaceMatch(type, todo, offset: offset);
      case FunctionType.substr:
        return _execSubstring(type, todo, offset: offset);
      case FunctionType.lower:
      case FunctionType.title:
      case FunctionType.upper:
        return _execToCase(type, todo, offset: offset);
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execDateTime(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var valueStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var addUnitsStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    var value = (valueStr.isBlank() ? DateTime.now() : DateTime.parse(valueStr));
    var addUnits = (addUnitsStr.isBlank() ? 0 : int.tryParse(addUnitsStr) ?? 0);
    var hasDate = true;
    var hasTime = ((value.hour != 0) || (value.minute != 0) || (value.second != 0) || (value.millisecond != 0));

    switch (type) {
      case FunctionType.addDays:
        value = (addUnits > 0 ? value.add(Duration(days: addUnits)) : value.subtract(Duration(days: -addUnits)));
        break;
      case FunctionType.addMonths:
        value = DateTime(value.year, value.month + addUnits, value.day, value.hour, value.minute, value.second, value.millisecond);
        break;
      case FunctionType.addYears:
        value = DateTime(value.year + addUnits, value.month, value.day, value.hour, value.minute, value.second, value.millisecond);
        break;
      case FunctionType.date:
        hasTime = false;
        break;
      case FunctionType.endOfMonth:
        hasTime = false;
        value = DateTime(value.year, value.month + 1, 1).subtract(Duration(days: 1));
        break;
      case FunctionType.local:
        value = DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch, isUtc: true).toLocal();
        break;
      case FunctionType.startOfMonth:
        hasTime = false;
        value = DateTime(value.year, value.month, 1);
        break;
      case FunctionType.time:
        hasDate = false;
        hasTime = true;
        break;
      case FunctionType.utc:
        value = value.toUtc();
        break;
      default:
        break;
    }

    String? resStr = value.toIso8601String();

    if (hasDate) {
      resStr = (hasTime ? resStr : resStr.substring(0, 10));
    }
    else {
      resStr = (hasTime ? resStr.substring(11) : null);
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:   $valueStr\n...add:     $addUnits\n...hasDate: $hasDate\n...hasTime: $hasTime\n...result:  $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execDateTimeNow(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var format = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    var now = DateTime.now();

    if (format.isNotEmpty) {
      return DateFormat(format).format(now);
    }

    var nowStr = now.toIso8601String();
    var resStr = nowStr;

    switch (type) {
      case FunctionType.today:
        resStr = nowStr.substring(0, 10);
        break;
      default:
        break;
    }

    if (logger.isDebug) {
      logger.debug('$type\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execFile(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var fileName = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var format = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    var stat = Path.fileSystem.file(fileName).statSync();

    if (stat.type == FileSystemEntityType.notFound) {
      stat = Path.fileSystem.directory(fileName).statSync();
    }

    var isFound = ((stat.type != FileSystemEntityType.notFound));
    var isFile = (isFound && ((stat.type != FileSystemEntityType.directory)));

    String? resStr;

    switch (type) {
      case FunctionType.baseName:
        resStr = Path.basename(fileName);
        break;
      case FunctionType.baseNameNoExt:
        resStr = Path.basenameWithoutExtension(fileName);
        break;
      case FunctionType.dirName:
        resStr = Path.dirname(fileName);
        break;
      case FunctionType.extension:
        resStr = Path.extension(fileName);
        break;
      case FunctionType.fileSize:
        resStr = FileExt.formatSize((isFile ? stat.size : -1), format);
        break;
      case FunctionType.lastModified:
        resStr = (isFound ? stat.modified.toIso8601String() : '');
        break;
      default:
        break;
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $fileName\n...format: $format\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIndex(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var fndStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var begPos = 0;
    var resStr = '0';

    if (inpStr.isNotEmpty && fndStr.isNotEmpty) {
      var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString() ?? '');
      begPos = (_toInt(begStr) ?? 1) - 1;
      var endPos = inpStr.length;

      switch (type) {
        case FunctionType.indexOf:
          resStr = (inpStr.indexOf(fndStr, (begPos <= 0 ? 0 : begPos)) + 1).toString();
          break;
        case FunctionType.lastIndexOf:
          resStr = (inpStr.lastIndexOf(fndStr, ((begPos > 0) && (begPos <= endPos) ? begPos : endPos)) + 1).toString();
          break;
        default:
          break;
      }
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $inpStr\n...find:   $fndStr\n...from:    $begPos\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIif(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var cndStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var yesStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var notStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    return (expression.exec({cndStr: yesStr, keywords.forElse: notStr})?.toString() ?? '');
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execLen(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var resStr = '';

    switch (type) {
      case FunctionType.len:
        resStr = inpStr.length.toStringAsFixed(0);
        break;
      default:
        break;
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $inpStr\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execMatch(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var patStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var resStr = '0';

    if (inpStr.isNotEmpty && patStr.isNotEmpty) {
      var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
      var regExp = _toRegExp(patStr, flgStr);

      if (regExp != null) {
        switch (type) {
          case FunctionType.match:
            var match = regExp.firstMatch(inpStr);
            resStr = ((match?.start ?? -1) + 1).toString();
            break;
          case FunctionType.lastMatch:
            var allMatches = regExp.allMatches(inpStr);
            if (allMatches.isNotEmpty) {
              resStr = (allMatches.last.start + 1).toString();
            }
            break;
          default:
            break;
        }
      }
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $inpStr\n...pattern: $patStr\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execMath(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var isUnary = false;

    switch (type) {
      case FunctionType.pi:
        return pi.toString();
      case FunctionType.ceil:
      case FunctionType.cos:
      case FunctionType.exp:
      case FunctionType.floor:
      case FunctionType.ln:
      case FunctionType.rad:
      case FunctionType.sin:
      case FunctionType.sqrt:
      case FunctionType.tan:
        isUnary = true;
        break;
      default:
        break;
    }

    var curNumericPrecision = (type == FunctionType.divInt ? 0 : numericPrecision);

    var cnt = todo.length;

    var o1 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var n1 = _toNum(o1, isInt: (curNumericPrecision == 0));

    if (n1 == null) {
      _fail(type, 'Bad 1st argument: $o1');
    }

    num? n2;
    String? o2;

    if (!isUnary) {
      o2 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
      n2 = _toNum(o2, isInt: (curNumericPrecision == 0));

      if (type == FunctionType.round) {
        if (n2 == null) {
          isUnary = true;
        }
        else {
          curNumericPrecision = n2.round();
        }
      }
      else if (n2 == null) {
        _fail(type, 'Bad 2nd argument: $o2');
      }
    }

    n2 ??= 0;

    switch (type) {
      case FunctionType.add:
        n1 += n2;
        break;
      case FunctionType.ceil:
        n1 = n1.ceil();
        break;
      case FunctionType.cos:
        n1 = cos(n1);
        break;
      case FunctionType.div:
      case FunctionType.divInt:
        n1 /= n2;
        break;
      case FunctionType.exp:
        n1 = exp(n1);
        break;
      case FunctionType.floor:
        n1 = n1.floor();
        break;
      case FunctionType.ln:
        n1 = log(n1);
        break;
      case FunctionType.max:
        n1 = (n1 >= n2 ? n1 : n2);
        break;
      case FunctionType.min:
        n1 = (n1 <= n2 ? n1 : n2);
        break;
      case FunctionType.mod:
        n1 %= n2;
        break;
      case FunctionType.mul:
        n1 *= n2;
        break;
      case FunctionType.pow:
        n1 = pow(n1, n2);
        break;
      case FunctionType.rad:
        n1 = ((n1 * pi) / 180.0);
        break;
      case FunctionType.round:
        break;
      case FunctionType.sin:
        n1 = sin(n1);
        break;
      case FunctionType.sqrt:
        n1 = sqrt(n1);
        break;
      case FunctionType.sub:
        n1 -= n2;
        break;
      case FunctionType.tan:
        n1 = tan(n1);
        break;
      default:
        break;
    }

    if (n1 is int) {
      curNumericPrecision = 0;
    }

    var resStr = n1.toStringAsFixed(curNumericPrecision);

    if (logger.isDebug) {
      if (isUnary) {
        logger.debug('$type\n...op:     $o1\n...result: $resStr');
      }
      else {
        logger.debug('$type\n...op1:    $o1\n...op2:    $o2\n...result: $resStr');
      }
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execReplace(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var srcStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var dstStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (srcStr.isEmpty) {
      _fail(type, 'search string (2nd param) should not be empty');
    }

    var resStr = inpStr.replaceAll(srcStr, dstStr);

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $inpStr\n...from:   $srcStr\n...to:     $dstStr\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execReplaceMatch(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isEmpty) {
      return inpStr;
    }

    var srcPat = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (srcPat.isEmpty) {
      _fail(type, 'undefined search pattern (2nd param)');
    }

    var dstStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    var regExp = _toRegExp(srcPat, flgStr);

    if (regExp == null) {
      _fail(type, 'invalid regular expression $srcPat');
    }

    var isGlobal = flgStr.contains('g');

    String resStr;

    if (dstStr.contains(r'$')) {
      if (isGlobal) {
        resStr = inpStr.replaceAllMapped(regExp, (match) => _execReplaceMatchProc(match, dstStr));
      }
      else {
        resStr = inpStr.replaceFirstMapped(regExp, (match) => _execReplaceMatchProc(match, dstStr));
      }
    }
    else if (isGlobal) {
      resStr = inpStr.replaceAll(regExp, dstStr);
    }
    else {
      resStr = inpStr.replaceFirst(regExp, dstStr);
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:   $inpStr\n...pattern: $srcPat\n...flags:   $flgStr\n...to:      $dstStr\n...result:  $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String _execReplaceMatchProc(Match match, String dstStr) {
    return dstStr.replaceAllMapped(_rexGroup, (groupMatch) {
      var s = groupMatch[1];

      if ((s != null) && s.isNotEmpty) {
        return s[1];
      }

      s = groupMatch[2];

      if ((s != null) && s.isNotEmpty) {
        return s[1];
      }

      s = (groupMatch[4] ?? groupMatch[5]);
      var groupNo = _toInt(s) ?? -1;

      if ((groupNo >= 0) && (groupNo <= match.groupCount)) {
        return match[groupNo] ?? '';
      }
      else {
        return '';
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execRun(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var txt = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var cmd = Command(text: txt, isToVar: true);

    if (logger.isDebug) {
      logger.debug('$type\n...command: ${cmd.toString()}\n');
    }

    return cmd.exec();
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execSubstring(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var lenStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (begStr.isEmpty) {
      _fail(type, 'undefined offset (2nd param)');
    }

    var begVal = _toInt(begStr) ?? 0;
    var lenVal = _toInt(lenStr) ?? 0;

    if (begVal <= 0) {
      _fail(type, 'The offset (2nd param) is not a number: $begStr');
    }

    --begVal;

    if (lenVal <= 0) {
      lenVal = (inpStr.length - begVal);
    }

    var endVal = begVal + lenVal;
    var resStr = inpStr.substring(begVal, endVal);

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $inpStr\n...beg:    $begVal\n...end:    $endVal\n...result: $resStr\n');
    }

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execToCase(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var sepStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isEmpty) {
      return inpStr;
    }

    String? resStr;

    switch (type) {
      case FunctionType.lower:
        resStr = inpStr.toLowerCase();
        break;
      case FunctionType.title:
        resStr = _toTitleCase(inpStr, sepStr);
        break;
      case FunctionType.upper:
        resStr = inpStr.toUpperCase();
        break;
      default:
        break;
    }

    if (logger.isDebug) {
      logger.debug('$type\n...input:  $inpStr\n...result: $resStr\n');
    } 

    return resStr;
  }

  //////////////////////////////////////////////////////////////////////////////

  Never _fail(FunctionType type, String msg) =>
    throw Exception('Invalid function "$type": $msg');

  //////////////////////////////////////////////////////////////////////////////

  void _initNameTypeMap() {
    nameTypeMap.clear();
    nameTypeMap[_toName(keywords.forFnAdd)] = FunctionType.add;
    nameTypeMap[_toName(keywords.forFnAddDays)] = FunctionType.addDays;
    nameTypeMap[_toName(keywords.forFnAddMonths)] = FunctionType.addMonths;
    nameTypeMap[_toName(keywords.forFnAddYears)] = FunctionType.addYears;
    nameTypeMap[_toName(keywords.forFnBaseName)] = FunctionType.baseName;
    nameTypeMap[_toName(keywords.forFnBaseNameNoExt)] = FunctionType.baseNameNoExt;
    nameTypeMap[_toName(keywords.forFnCeil)] = FunctionType.ceil;
    nameTypeMap[_toName(keywords.forFnCos)] = FunctionType.cos;
    nameTypeMap[_toName(keywords.forFnDate)] = FunctionType.date;
    nameTypeMap[_toName(keywords.forFnDirName)] = FunctionType.dirName;
    nameTypeMap[_toName(keywords.forFnDiv)] = FunctionType.div;
    nameTypeMap[_toName(keywords.forFnDivInt)] = FunctionType.divInt;
    nameTypeMap[_toName(keywords.forFnEndOfMonth)] = FunctionType.endOfMonth;
    nameTypeMap[_toName(keywords.forFnExp)] = FunctionType.exp;
    nameTypeMap[_toName(keywords.forFnExtension)] = FunctionType.extension;
    nameTypeMap[_toName(keywords.forFnFileSize)] = FunctionType.fileSize;
    nameTypeMap[_toName(keywords.forFnFloor)] = FunctionType.floor;
    nameTypeMap[_toName(keywords.forFnIif)] = FunctionType.iif;
    nameTypeMap[_toName(keywords.forFnIndex)] = FunctionType.indexOf;
    nameTypeMap[_toName(keywords.forFnMatch)] = FunctionType.match;
    nameTypeMap[_toName(keywords.forFnLastIndex)] = FunctionType.lastIndexOf;
    nameTypeMap[_toName(keywords.forFnLastMatch)] = FunctionType.lastMatch;
    nameTypeMap[_toName(keywords.forFnLastModified)] = FunctionType.lastModified;
    nameTypeMap[_toName(keywords.forFnLen)] = FunctionType.len;
    nameTypeMap[_toName(keywords.forFnLn)] = FunctionType.ln;
    nameTypeMap[_toName(keywords.forFnLocal)] = FunctionType.local;
    nameTypeMap[_toName(keywords.forFnLower)] = FunctionType.lower;
    nameTypeMap[_toName(keywords.forFnMax)] = FunctionType.max;
    nameTypeMap[_toName(keywords.forFnMin)] = FunctionType.min;
    nameTypeMap[_toName(keywords.forFnMod)] = FunctionType.mod;
    nameTypeMap[_toName(keywords.forFnMul)] = FunctionType.mul;
    nameTypeMap[_toName(keywords.forFnNow)] = FunctionType.now;
    nameTypeMap[_toName(keywords.forFnPi)] = FunctionType.pi;
    nameTypeMap[_toName(keywords.forFnPow)] = FunctionType.pow;
    nameTypeMap[_toName(keywords.forFnRad)] = FunctionType.rad;
    nameTypeMap[_toName(keywords.forFnReplace)] = FunctionType.replace;
    nameTypeMap[_toName(keywords.forFnReplaceMatch)] = FunctionType.replaceMatch;
    nameTypeMap[_toName(keywords.forFnRound)] = FunctionType.round;
    nameTypeMap[_toName(keywords.forFnRun)] = FunctionType.run;
    nameTypeMap[_toName(keywords.forFnStartOfMonth)] = FunctionType.startOfMonth;
    nameTypeMap[_toName(keywords.forFnSin)] = FunctionType.sin;
    nameTypeMap[_toName(keywords.forFnSqrt)] = FunctionType.sqrt;
    nameTypeMap[_toName(keywords.forFnSub)] = FunctionType.sub;
    nameTypeMap[_toName(keywords.forFnSubstr)] = FunctionType.substr;
    nameTypeMap[_toName(keywords.forFnTan)] = FunctionType.tan;
    nameTypeMap[_toName(keywords.forFnTime)] = FunctionType.time;
    nameTypeMap[_toName(keywords.forFnTitle)] = FunctionType.title;
    nameTypeMap[_toName(keywords.forFnToday)] = FunctionType.today;
    nameTypeMap[_toName(keywords.forFnUpper)] = FunctionType.upper;
    nameTypeMap[_toName(keywords.forFnUtc)] = FunctionType.utc;
  }

  //////////////////////////////////////////////////////////////////////////////

  int? _toInt(String? input) {
    if (input == null) {
      return null;
    }
    
    var n = num.tryParse(input);

    if (n == null) {
      return null;
    }

    return ((n % 1) == 0 ? n.floor() : null);
  }

  //////////////////////////////////////////////////////////////////////////////

  String _toName(String input) =>
    input.trim().toLowerCase();

  //////////////////////////////////////////////////////////////////////////////

  num? _toNum(String? input, {bool isInt = false}) {
    if (input == null) {
      return null;
    }

    var i = int.tryParse(input);

    if (isInt || (i != null)) {
      return i;
    }

    return num.tryParse(input);
  }

  //////////////////////////////////////////////////////////////////////////////

  RegExp? _toRegExp(String? pattern, String? flags) {
    if (pattern == null) {
      return null;
    }

    flags ??= '';

    return RegExp(
      pattern,
      caseSensitive: !flags.contains('i'),
      dotAll: flags.contains('s'),
      multiLine: flags.contains('m'),
      unicode: flags.contains('u'),
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  String _toTitleCase(String input, String separators){
    var escSep = (separators.isEmpty ? r'\s' : RegExp.escape(separators).replaceAll(' ', r'\s'));
    var rexSep = RegExp('(^|[$escSep]+)([^$escSep])');

    var result = input.replaceAllMapped(rexSep, (m) {
      return (m.group(1) ?? '') + (m.group(2)?.toUpperCase() ?? '');
    });

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

}