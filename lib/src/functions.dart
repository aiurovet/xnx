import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:xnx/src/command.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/ext/string.dart';

enum FunctionType {
  unknown,
  add,
  addDays,
  addMonths,
  addYears,
  date,
  div,
  divInt,
  endOfMonth,
  fileSize,
  indexOf,
  lastIndexOf,
  lastMatch,
  lastModified,
  match,
  local,
  lower,
  max,
  min,
  mod,
  mul,
  now,
  replace,
  replaceMatch,
  run,
  sub,
  substr,
  startOfMonth,
  time,
  today,
  upper,
  utc,
}

class Functions {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _rexGroup = RegExp(r'(\\\\)|(\\\$)|(\$([\d]+))|\$\{([\d]+)\}');

  //////////////////////////////////////////////////////////////////////////////
  // Protected members
  //////////////////////////////////////////////////////////////////////////////

  @protected final FlatMap flatMap;
  @protected final Keywords keywords;
  @protected final Map<String, FunctionType> nameTypeMap = {};

  //////////////////////////////////////////////////////////////////////////////

  Functions({required this.flatMap, required this.keywords}) {
    _initNameTypeMap();
  }

  //////////////////////////////////////////////////////////////////////////////

  Object? exec(Object? todo, {int offset = 0}) {
    if (todo is List) {
      if (todo.isNotEmpty) {
        var name = _toName(todo[0]);
        var type = nameTypeMap[name];

        if ((type != null) && (type != FunctionType.unknown)) {
          return _exec(type, todo, offset: offset);
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

  Object? _exec(FunctionType type, List<Object?> todo, {int offset = 0}) {
    switch (type) {
      case FunctionType.add:
      case FunctionType.div:
      case FunctionType.divInt:
      case FunctionType.max:
      case FunctionType.min:
      case FunctionType.mod:
      case FunctionType.mul:
      case FunctionType.sub:
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
      case FunctionType.fileSize:
      case FunctionType.lastModified:
        return _execFile(type, todo, offset: offset);
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
        return null;
    }

    valueStr = value.toIso8601String();

    if (hasDate) {
      return (hasTime ? valueStr : valueStr.substring(0, 10));
    }
    else {
      return (hasTime ? valueStr.substring(11) : null);
    }
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

    switch (type) {
      case FunctionType.today:
        return nowStr.substring(0, 10);
      default:
        return nowStr;
    }
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

    switch (type) {
      case FunctionType.fileSize:
        return FileExt.formatSize((isFile ? stat.size : -1), format);
      case FunctionType.lastModified:
        return (isFound ? stat.modified.toIso8601String() : '');
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIndex(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var fndStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isNotEmpty && fndStr.isNotEmpty) {
      var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString() ?? '');
      var begPos = (_toInt(begStr) ?? 1) - 1;
      var endPos = inpStr.length;

      switch (type) {
        case FunctionType.indexOf:
          return (inpStr.indexOf(fndStr, (begPos <= 0 ? 0 : begPos)) + 1).toString();
        case FunctionType.lastIndexOf:
          return (inpStr.lastIndexOf(fndStr, ((begPos > 0) && (begPos <= endPos) ? begPos : endPos)) + 1).toString();
        default:
          break;
      }
    }

    return '0';
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execMatch(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var patStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isNotEmpty && patStr.isNotEmpty) {
      var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
      var regExp = _toRegExp(patStr, flgStr);

      if (regExp != null) {
        switch (type) {
          case FunctionType.match:
            var match = regExp.firstMatch(inpStr);
            return ((match?.start ?? -1) + 1).toString();
          case FunctionType.lastMatch:
            var allMatches = regExp.allMatches(inpStr);
            if (allMatches.isNotEmpty) {
              return (allMatches.last.start + 1).toString();
            }
            break;
          default:
            break;
        }
      }
    }

    return '0';
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execMath(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;
    var isInt = (type == FunctionType.divInt);

    var o1 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var n1 = _toNum(o1, isInt: isInt);

    if (n1 == null) {
      _fail(type, 'Bad 1st argument: $o1');
    }

    var o2 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var n2 = _toNum(o2, isInt: isInt);

    if (n2 == null) {
      _fail(type, 'Bad 2nd argument: $o2');
    }

    switch (type) {
      case FunctionType.add:
        return (n1 + n2).toString();
      case FunctionType.div:
        return (n1 / n2).toString();
      case FunctionType.divInt:
        return (n1 / n2).toStringAsFixed(0);
      case FunctionType.max:
        return (n1 >= n2 ? n1 : n2).toString();
      case FunctionType.min:
        return (n1 <= n2 ? n1 : n2).toString();
      case FunctionType.mod:
        return (n1 % n2).toString();
      case FunctionType.mul:
        return (n1 * n2).toString();
      case FunctionType.sub:
        return (n1 - n2).toString();
      default:
        return null;
    }
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

    return inpStr.replaceAll(srcStr, dstStr);
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

    if (lenStr.isEmpty) {
      _fail(type, 'undefined length (3rd param)');
    }

    var begVal = _toInt(begStr) ?? 0;
    var lenVal = _toInt(lenStr) ?? 0;

    if (begVal <= 0) {
      _fail(type, 'The offset (2nd param) is not a number');
    }

    --begVal;

    if (lenVal <= 0) {
      lenVal = (inpStr.length - begVal);
    }

    return inpStr.substring(begVal, begVal + lenVal);
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execToCase(FunctionType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isEmpty) {
      return inpStr;
    }

    switch (type) {
      case FunctionType.lower:
        return inpStr.toLowerCase();
      case FunctionType.upper:
        return inpStr.toUpperCase();
      default:
        return null;
    }
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
    nameTypeMap[_toName(keywords.forFnDate)] = FunctionType.date;
    nameTypeMap[_toName(keywords.forFnDiv)] = FunctionType.div;
    nameTypeMap[_toName(keywords.forFnDivInt)] = FunctionType.divInt;
    nameTypeMap[_toName(keywords.forFnEndOfMonth)] = FunctionType.endOfMonth;
    nameTypeMap[_toName(keywords.forFnFileSize)] = FunctionType.fileSize;
    nameTypeMap[_toName(keywords.forFnIndex)] = FunctionType.indexOf;
    nameTypeMap[_toName(keywords.forFnMatch)] = FunctionType.match;
    nameTypeMap[_toName(keywords.forFnLastIndex)] = FunctionType.lastIndexOf;
    nameTypeMap[_toName(keywords.forFnLastMatch)] = FunctionType.lastMatch;
    nameTypeMap[_toName(keywords.forFnLastModified)] = FunctionType.lastModified;
    nameTypeMap[_toName(keywords.forFnLocal)] = FunctionType.local;
    nameTypeMap[_toName(keywords.forFnLower)] = FunctionType.lower;
    nameTypeMap[_toName(keywords.forFnMax)] = FunctionType.max;
    nameTypeMap[_toName(keywords.forFnMin)] = FunctionType.min;
    nameTypeMap[_toName(keywords.forFnMod)] = FunctionType.mod;
    nameTypeMap[_toName(keywords.forFnMul)] = FunctionType.mul;
    nameTypeMap[_toName(keywords.forFnNow)] = FunctionType.now;
    nameTypeMap[_toName(keywords.forFnReplace)] = FunctionType.replace;
    nameTypeMap[_toName(keywords.forFnReplaceMatch)] = FunctionType.replaceMatch;
    nameTypeMap[_toName(keywords.forFnRun)] = FunctionType.run;
    nameTypeMap[_toName(keywords.forFnStartOfMonth)] = FunctionType.startOfMonth;
    nameTypeMap[_toName(keywords.forFnSub)] = FunctionType.sub;
    nameTypeMap[_toName(keywords.forFnSubstr)] = FunctionType.substr;
    nameTypeMap[_toName(keywords.forFnTime)] = FunctionType.time;
    nameTypeMap[_toName(keywords.forFnToday)] = FunctionType.today;
    nameTypeMap[_toName(keywords.forFnUpper)] = FunctionType.upper;
    nameTypeMap[_toName(keywords.forFnUtc)] = FunctionType.utc;
  }

  //////////////////////////////////////////////////////////////////////////////

  int? _toInt(String? input) =>
    (input == null ? null : int.tryParse(input));

  //////////////////////////////////////////////////////////////////////////////

  String _toName(String input) =>
    input.trim().toLowerCase();

  //////////////////////////////////////////////////////////////////////////////

  num? _toNum(String? input, {bool isInt = false}) =>
    (input == null ? null : (isInt ? int.tryParse(input) : num.tryParse(input)));

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

}