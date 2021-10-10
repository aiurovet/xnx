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
  Unknown,
  Add,
  AddDays,
  AddMonths,
  AddYears,
  Date,
  Div,
  EndOfMonth,
  FileSize,
  Index,
  LastIndex,
  LastMatch,
  LastModified,
  Match,
  Local,
  Lower,
  Max,
  Min,
  Mod,
  Mul,
  Now,
  Replace,
  ReplaceMatch,
  Run,
  Sub,
  Substr,
  StartOfMonth,
  Time,
  Today,
  Upper,
  Utc,
}

class Transformation {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final RegExp _RE_GROUP = RegExp(r'(\\\\)|(\\\$)|(\$([\d]+))|\$\{([\d]+)\}');

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

        if ((type != null) && (type != TransformationType.Unknown)) {
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
        var type = nameTypeMap[name] ?? TransformationType.Unknown;
        Object? newValue;

        if (type == TransformationType.Unknown) {
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

    return todo;
  }

  //////////////////////////////////////////////////////////////////////////////

  Object? _exec(TransformationType type, List<Object?> todo, {int offset = 0}) {
    switch (type) {
      case TransformationType.Add:
      case TransformationType.Div:
      case TransformationType.Max:
      case TransformationType.Min:
      case TransformationType.Mod:
      case TransformationType.Mul:
      case TransformationType.Sub:
        return _execMath(type, todo, offset: offset);
      case TransformationType.AddDays:
      case TransformationType.AddMonths:
      case TransformationType.AddYears:
      case TransformationType.Date:
      case TransformationType.EndOfMonth:
      case TransformationType.Local:
      case TransformationType.StartOfMonth:
      case TransformationType.Time:
      case TransformationType.Utc:
        return _execDateTime(type, todo, offset: offset);
      case TransformationType.FileSize:
      case TransformationType.LastModified:
        return _execFile(type, todo, offset: offset);
      case TransformationType.Index:
      case TransformationType.LastIndex:
        return _execIndex(type, todo, offset: offset);
      case TransformationType.LastMatch:
      case TransformationType.Match:
        return _execMatch(type, todo, offset: offset);
      case TransformationType.Run:
        return _execRun(type, todo, offset: offset);
      case TransformationType.Now:
      case TransformationType.Today:
        return _execDateTimeNow(type, todo, offset: offset);
      case TransformationType.Replace:
        return _execReplace(type, todo, offset: offset);
      case TransformationType.ReplaceMatch:
        return _execReplaceMatch(type, todo, offset: offset);
      case TransformationType.Substr:
        return _execSubstring(type, todo, offset: offset);
      case TransformationType.Lower:
      case TransformationType.Upper:
        return _execToCase(type, todo, offset: offset);
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execDateTime(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var valueStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var addUnitsStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    var value = ((valueStr == null) || valueStr.isBlank() ? DateTime.now() : DateTime.parse(valueStr));
    var addUnits = (addUnitsStr == null ? 0 : int.tryParse(addUnitsStr) ?? 0);
    var hasDate = true;
    var hasTime = ((value.hour != 0) || (value.minute != 0) || (value.second != 0) || (value.millisecond != 0));

    switch (type) {
      case TransformationType.AddDays:
        value = (addUnits > 0 ? value.add(Duration(days: addUnits)) : value.subtract(Duration(days: -addUnits)));
        break;
      case TransformationType.AddMonths:
        value = DateTime(value.year, value.month + addUnits, value.day, value.hour, value.minute, value.second, value.millisecond);
        break;
      case TransformationType.AddYears:
        value = DateTime(value.year + addUnits, value.month, value.day, value.hour, value.minute, value.second, value.millisecond);
        break;
      case TransformationType.Date:
        hasTime = false;
        break;
      case TransformationType.EndOfMonth:
        hasTime = false;
        value = DateTime(value.year, value.month + 1, 1).subtract(Duration(days: 1));
        break;
      case TransformationType.Local:
        value = DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch, isUtc: true).toLocal();
        break;
      case TransformationType.StartOfMonth:
        hasTime = false;
        value = DateTime(value.year, value.month, 1);
        break;
      case TransformationType.Time:
        hasDate = false;
        hasTime = true;
        break;
      case TransformationType.Utc:
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

    var format = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    format = flatMap.expand(format);

    var now = DateTime.now();

    if (format.isNotEmpty) {
      return DateFormat(format).format(now);
    }

    var nowStr = now.toIso8601String();

    switch (type) {
      case TransformationType.Today:
        return nowStr.substring(0, 10);
      default:
        return nowStr;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execFile(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var fileName = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var format = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    var stat = Path.fileSystem.file(fileName).statSync();

    if (stat.type == FileSystemEntityType.notFound) {
      stat = Path.fileSystem.directory(fileName).statSync();
    }

    var isFound = ((stat.type != FileSystemEntityType.notFound));
    var isFile = (isFound && ((stat.type != FileSystemEntityType.directory)));

    switch (type) {
      case TransformationType.FileSize:
        return FileExt.formatSize((isFile ? stat.size : -1), format ?? '');
      case TransformationType.LastModified:
        return (isFound ? stat.modified.toIso8601String() : '');
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIndex(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var fndStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if ((inpStr != null) && inpStr.isNotEmpty &&
        (fndStr != null) && fndStr.isNotEmpty) {
      var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
      var begPos = (_toInt(begStr) ?? 1) - 1;
      var endPos = inpStr.length;

      switch (type) {
        case TransformationType.Index:
          return (inpStr.indexOf(fndStr, (begPos <= 0 ? 0 : begPos)) + 1).toString();
        case TransformationType.LastIndex:
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

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var patStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if ((inpStr != null) && inpStr.isNotEmpty &&
        (patStr != null) && patStr.isNotEmpty) {
      var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
      var regExp = _toRegExp(patStr, flgStr);

      if (regExp != null) {
        switch (type) {
          case TransformationType.Match:
            var match = regExp.firstMatch(inpStr);
            return ((match?.start ?? -1) + 1).toString();
          case TransformationType.LastMatch:
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

    var o1 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var n1 = _toNum(o1);

    if (n1 == null) {
      _fail(type, 'Bad argument #1');
    }

    var o2 = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var n2 = _toNum(o2);

    if (n2 == null) {
      _fail(type, 'Bad argument #2');
    }

    switch (type) {
      case TransformationType.Add:
        return (n1 + n2).toString();
      case TransformationType.Div:
        return (n1 / n2).toString();
      case TransformationType.Max:
        return (n1 >= n2 ? n1 : n2).toString();
      case TransformationType.Min:
        return (n1 <= n2 ? n1 : n2).toString();
      case TransformationType.Mod:
        return (n1 % n2).toString();
      case TransformationType.Mul:
        return (n1 * n2).toString();
      case TransformationType.Sub:
        return (n1 - n2).toString();
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execReplace(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var srcStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var dstStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if (inpStr == null) {
      _fail(type, 'undefined input string (1st param)');
    }

    if (srcStr == null) {
      _fail(type, 'undefined search string (2nd param)');
    }

    inpStr = flatMap.expand(inpStr);

    return inpStr.replaceAll(srcStr, dstStr ?? '');
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execReplaceMatch(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if ((inpStr == null) || inpStr.isEmpty) {
      return '';
    }

    var srcPat = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if ((srcPat == null) || srcPat.isEmpty) {
      _fail(type, 'undefined search pattern (2nd param)');
    }

    var dstStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString()) ?? '';
    var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    var regExp = _toRegExp(srcPat, flgStr);

    if (regExp == null) {
      _fail(type, 'invalid regular expression $srcPat');
    }

    var isGlobal = flgStr?.contains('g') ?? false;

    inpStr = flatMap.expand(inpStr);

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
    return dstStr.replaceAllMapped(_RE_GROUP, (groupMatch) {
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

    var txt = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var cmd = Command(text: txt, isToVar: true);

    return cmd.exec();
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execSubstring(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var lenStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if (inpStr == null) {
      _fail(type, 'undefined input string (1st param)');
    }

    if (begStr == null) {
      _fail(type, 'undefined offset (2nd param)');
    }

    var begVal = _toInt(begStr) ?? 0;
    var lenVal = _toInt(lenStr) ?? 0;

    if (begVal <= 0) {
      _fail(type, 'The offset (2nd param) is not a number');
    }

    --begVal;
    inpStr = flatMap.expand(inpStr);

    if (lenVal <= 0) {
      lenVal = (inpStr.length - begVal);
    }

    return inpStr.substring(begVal, begVal + lenVal);
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execToCase(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if (inpStr == null) {
      _fail(type, 'undefined input string');
    }

    inpStr = flatMap.expand(inpStr);

    switch (type) {
      case TransformationType.Lower:
        return inpStr.toLowerCase();
      case TransformationType.Upper:
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
    nameTypeMap[_toName(keywords.forFnAdd)] = TransformationType.Add;
    nameTypeMap[_toName(keywords.forFnAddDays)] = TransformationType.AddDays;
    nameTypeMap[_toName(keywords.forFnAddMonths)] = TransformationType.AddMonths;
    nameTypeMap[_toName(keywords.forFnAddYears)] = TransformationType.AddYears;
    nameTypeMap[_toName(keywords.forFnDate)] = TransformationType.Date;
    nameTypeMap[_toName(keywords.forFnDiv)] = TransformationType.Div;
    nameTypeMap[_toName(keywords.forFnEndOfMonth)] = TransformationType.EndOfMonth;
    nameTypeMap[_toName(keywords.forFnFileSize)] = TransformationType.FileSize;
    nameTypeMap[_toName(keywords.forFnIndex)] = TransformationType.Index;
    nameTypeMap[_toName(keywords.forFnMatch)] = TransformationType.Match;
    nameTypeMap[_toName(keywords.forFnLastIndex)] = TransformationType.LastIndex;
    nameTypeMap[_toName(keywords.forFnLastMatch)] = TransformationType.LastMatch;
    nameTypeMap[_toName(keywords.forFnLastModified)] = TransformationType.LastModified;
    nameTypeMap[_toName(keywords.forFnLocal)] = TransformationType.Local;
    nameTypeMap[_toName(keywords.forFnLower)] = TransformationType.Lower;
    nameTypeMap[_toName(keywords.forFnMax)] = TransformationType.Max;
    nameTypeMap[_toName(keywords.forFnMin)] = TransformationType.Min;
    nameTypeMap[_toName(keywords.forFnMod)] = TransformationType.Mod;
    nameTypeMap[_toName(keywords.forFnMul)] = TransformationType.Mul;
    nameTypeMap[_toName(keywords.forFnNow)] = TransformationType.Now;
    nameTypeMap[_toName(keywords.forFnReplace)] = TransformationType.Replace;
    nameTypeMap[_toName(keywords.forFnReplaceMatch)] = TransformationType.ReplaceMatch;
    nameTypeMap[_toName(keywords.forFnRun)] = TransformationType.Run;
    nameTypeMap[_toName(keywords.forFnStartOfMonth)] = TransformationType.StartOfMonth;
    nameTypeMap[_toName(keywords.forFnSub)] = TransformationType.Sub;
    nameTypeMap[_toName(keywords.forFnSubstr)] = TransformationType.Substr;
    nameTypeMap[_toName(keywords.forFnTime)] = TransformationType.Time;
    nameTypeMap[_toName(keywords.forFnToday)] = TransformationType.Today;
    nameTypeMap[_toName(keywords.forFnUpper)] = TransformationType.Upper;
    nameTypeMap[_toName(keywords.forFnUtc)] = TransformationType.Utc;
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