import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:xnx/src/command.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/ext/string.dart';

enum TransformationType {
  unknown,
  add,
  addDays,
  addMonths,
  addYears,
  date,
  div,
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

class Transformation {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _rexGroup = RegExp(r'(\\\\)|(\\\$)|(\$([\d]+))|\$\{([\d]+)\}');

  //////////////////////////////////////////////////////////////////////////////
  // Protected members
  //////////////////////////////////////////////////////////////////////////////

  @protected final FlatMap flatMap;
  @protected final Keywords keywords;
  @protected final Map<String, TransformationType> nameTypeMap = {};

  //////////////////////////////////////////////////////////////////////////////

  Transformation({required this.flatMap, required this.keywords}) {
    _initNameTypeMap();
  }

  //////////////////////////////////////////////////////////////////////////////

  Object? exec(Object? todo, {int offset = 0}) {
    if (todo is List) {
      if (todo.isNotEmpty) {
        var name = _toName(todo[0]);
        var type = nameTypeMap[name];

        if ((type != null) && (type != TransformationType.unknown)) {
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
        var type = nameTypeMap[name] ?? TransformationType.unknown;
        Object? newValue;

        if (type == TransformationType.unknown) {
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

  Object? _exec(TransformationType type, List<Object?> todo, {int offset = 0}) {
    switch (type) {
      case TransformationType.add:
      case TransformationType.div:
      case TransformationType.max:
      case TransformationType.min:
      case TransformationType.mod:
      case TransformationType.mul:
      case TransformationType.sub:
        return _execMath(type, todo, offset: offset);
      case TransformationType.addDays:
      case TransformationType.addMonths:
      case TransformationType.addYears:
      case TransformationType.date:
      case TransformationType.endOfMonth:
      case TransformationType.local:
      case TransformationType.startOfMonth:
      case TransformationType.time:
      case TransformationType.utc:
        return _execDateTime(type, todo, offset: offset);
      case TransformationType.fileSize:
      case TransformationType.lastModified:
        return _execFile(type, todo, offset: offset);
      case TransformationType.indexOf:
      case TransformationType.lastIndexOf:
        return _execIndex(type, todo, offset: offset);
      case TransformationType.lastMatch:
      case TransformationType.match:
        return _execMatch(type, todo, offset: offset);
      case TransformationType.run:
        return _execRun(type, todo, offset: offset);
      case TransformationType.now:
      case TransformationType.today:
        return _execDateTimeNow(type, todo, offset: offset);
      case TransformationType.replace:
        return _execReplace(type, todo, offset: offset);
      case TransformationType.replaceMatch:
        return _execReplaceMatch(type, todo, offset: offset);
      case TransformationType.substr:
        return _execSubstring(type, todo, offset: offset);
      case TransformationType.lower:
      case TransformationType.upper:
        return _execToCase(type, todo, offset: offset);
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execDateTime(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var valueStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var addUnitsStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    var value = (valueStr.isBlank() ? DateTime.now() : DateTime.parse(valueStr));
    var addUnits = (addUnitsStr.isBlank() ? 0 : int.tryParse(addUnitsStr) ?? 0);
    var hasDate = true;
    var hasTime = ((value.hour != 0) || (value.minute != 0) || (value.second != 0) || (value.millisecond != 0));

    switch (type) {
      case TransformationType.addDays:
        value = (addUnits > 0 ? value.add(Duration(days: addUnits)) : value.subtract(Duration(days: -addUnits)));
        break;
      case TransformationType.addMonths:
        value = DateTime(value.year, value.month + addUnits, value.day, value.hour, value.minute, value.second, value.millisecond);
        break;
      case TransformationType.addYears:
        value = DateTime(value.year + addUnits, value.month, value.day, value.hour, value.minute, value.second, value.millisecond);
        break;
      case TransformationType.date:
        hasTime = false;
        break;
      case TransformationType.endOfMonth:
        hasTime = false;
        value = DateTime(value.year, value.month + 1, 1).subtract(Duration(days: 1));
        break;
      case TransformationType.local:
        value = DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch, isUtc: true).toLocal();
        break;
      case TransformationType.startOfMonth:
        hasTime = false;
        value = DateTime(value.year, value.month, 1);
        break;
      case TransformationType.time:
        hasDate = false;
        hasTime = true;
        break;
      case TransformationType.utc:
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

  String? _execDateTimeNow(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var format = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    var now = DateTime.now();

    if (format.isNotEmpty) {
      return DateFormat(format).format(now);
    }

    var nowStr = now.toIso8601String();

    switch (type) {
      case TransformationType.today:
        return nowStr.substring(0, 10);
      default:
        return nowStr;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execFile(TransformationType type, List<Object?> todo, {int offset = 0}) {
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
      case TransformationType.fileSize:
        return FileExt.formatSize((isFile ? stat.size : -1), format);
      case TransformationType.lastModified:
        return (isFound ? stat.modified.toIso8601String() : '');
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIndex(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var fndStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isNotEmpty && fndStr.isNotEmpty) {
      var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString() ?? '');
      var begPos = (_toInt(begStr) ?? 1) - 1;
      var endPos = inpStr.length;

      switch (type) {
        case TransformationType.indexOf:
          return (inpStr.indexOf(fndStr, (begPos <= 0 ? 0 : begPos)) + 1).toString();
        case TransformationType.lastIndexOf:
          return (inpStr.lastIndexOf(fndStr, ((begPos > 0) && (begPos <= endPos) ? begPos : endPos)) + 1).toString();
        default:
          break;
      }
    }

    return '0';
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execMatch(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var patStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isNotEmpty && patStr.isNotEmpty) {
      var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
      var regExp = _toRegExp(patStr, flgStr);

      if (regExp != null) {
        switch (type) {
          case TransformationType.match:
            var match = regExp.firstMatch(inpStr);
            return ((match?.start ?? -1) + 1).toString();
          case TransformationType.lastMatch:
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

  String? _execMath(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var o1 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var n1 = _toNum(o1);

    if (n1 == null) {
      _fail(type, 'Bad 1st argument: $o1');
    }

    var o2 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var n2 = _toNum(o2);

    if (n2 == null) {
      _fail(type, 'Bad 2nd argument: $o2');
    }

    switch (type) {
      case TransformationType.add:
        return (n1 + n2).toString();
      case TransformationType.div:
        return (n1 / n2).toString();
      case TransformationType.max:
        return (n1 >= n2 ? n1 : n2).toString();
      case TransformationType.min:
        return (n1 <= n2 ? n1 : n2).toString();
      case TransformationType.mod:
        return (n1 % n2).toString();
      case TransformationType.mul:
        return (n1 * n2).toString();
      case TransformationType.sub:
        return (n1 - n2).toString();
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execReplace(TransformationType type, List<Object?> todo, {int offset = 0}) {
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

  String? _execReplaceMatch(TransformationType type, List<Object?> todo, {int offset = 0}) {
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

  String? _execRun(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var txt = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var cmd = Command(text: txt, isToVar: true);

    return cmd.exec();
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execSubstring(TransformationType type, List<Object?> todo, {int offset = 0}) {
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

  String? _execToCase(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';

    if (inpStr.isEmpty) {
      return inpStr;
    }

    switch (type) {
      case TransformationType.lower:
        return inpStr.toLowerCase();
      case TransformationType.upper:
        return inpStr.toUpperCase();
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Never _fail(TransformationType type, String msg) =>
    throw Exception('Invalid transformation "$type": $msg');

  //////////////////////////////////////////////////////////////////////////////

  void _initNameTypeMap() {
    nameTypeMap.clear();
    nameTypeMap[_toName(keywords.forFnAdd)] = TransformationType.add;
    nameTypeMap[_toName(keywords.forFnAddDays)] = TransformationType.addDays;
    nameTypeMap[_toName(keywords.forFnAddMonths)] = TransformationType.addMonths;
    nameTypeMap[_toName(keywords.forFnAddYears)] = TransformationType.addYears;
    nameTypeMap[_toName(keywords.forFnDate)] = TransformationType.date;
    nameTypeMap[_toName(keywords.forFnDiv)] = TransformationType.div;
    nameTypeMap[_toName(keywords.forFnEndOfMonth)] = TransformationType.endOfMonth;
    nameTypeMap[_toName(keywords.forFnFileSize)] = TransformationType.fileSize;
    nameTypeMap[_toName(keywords.forFnIndex)] = TransformationType.indexOf;
    nameTypeMap[_toName(keywords.forFnMatch)] = TransformationType.match;
    nameTypeMap[_toName(keywords.forFnLastIndex)] = TransformationType.lastIndexOf;
    nameTypeMap[_toName(keywords.forFnLastMatch)] = TransformationType.lastMatch;
    nameTypeMap[_toName(keywords.forFnLastModified)] = TransformationType.lastModified;
    nameTypeMap[_toName(keywords.forFnLocal)] = TransformationType.local;
    nameTypeMap[_toName(keywords.forFnLower)] = TransformationType.lower;
    nameTypeMap[_toName(keywords.forFnMax)] = TransformationType.max;
    nameTypeMap[_toName(keywords.forFnMin)] = TransformationType.min;
    nameTypeMap[_toName(keywords.forFnMod)] = TransformationType.mod;
    nameTypeMap[_toName(keywords.forFnMul)] = TransformationType.mul;
    nameTypeMap[_toName(keywords.forFnNow)] = TransformationType.now;
    nameTypeMap[_toName(keywords.forFnReplace)] = TransformationType.replace;
    nameTypeMap[_toName(keywords.forFnReplaceMatch)] = TransformationType.replaceMatch;
    nameTypeMap[_toName(keywords.forFnRun)] = TransformationType.run;
    nameTypeMap[_toName(keywords.forFnStartOfMonth)] = TransformationType.startOfMonth;
    nameTypeMap[_toName(keywords.forFnSub)] = TransformationType.sub;
    nameTypeMap[_toName(keywords.forFnSubstr)] = TransformationType.substr;
    nameTypeMap[_toName(keywords.forFnTime)] = TransformationType.time;
    nameTypeMap[_toName(keywords.forFnToday)] = TransformationType.today;
    nameTypeMap[_toName(keywords.forFnUpper)] = TransformationType.upper;
    nameTypeMap[_toName(keywords.forFnUtc)] = TransformationType.utc;
  }

  //////////////////////////////////////////////////////////////////////////////

  int? _toInt(String? input) =>
    (input == null ? null : int.tryParse(input));

  //////////////////////////////////////////////////////////////////////////////

  String _toName(String input) =>
    input.trim().toLowerCase();

  //////////////////////////////////////////////////////////////////////////////

  num? _toNum(String? input) =>
    (input == null ? null : num.tryParse(input));

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