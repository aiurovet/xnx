import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:xnx/src/command.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';

enum TransformationType {
  Unknown,
  Add,
  Div,
  Index,
  IndexRegExp,
  LastIndex,
  LastIndexRegExp,
  Max,
  Min,
  Mod,
  Mul,
  Now,
  Replace,
  ReplaceRegExp,
  Run,
  Sub,
  Substring,
  TimeNow,
  Today,
  ToLowerCase,
  ToUpperCase,
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

        flatMap[key] = newValue?.toString();
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
      case TransformationType.Index:
      case TransformationType.LastIndex:
        return _execIndex(type, todo, offset: offset);
      case TransformationType.IndexRegExp:
      case TransformationType.LastIndexRegExp:
        return _execIndexRegExp(type, todo, offset: offset);
      case TransformationType.Run:
        return _execExecute(type, todo, offset: offset);
      case TransformationType.Today:
      case TransformationType.Now:
      case TransformationType.TimeNow:
        return _execDateTime(type, todo, offset: offset);
      case TransformationType.Replace:
        return _execReplace(type, todo, offset: offset);
      case TransformationType.ReplaceRegExp:
        return _execReplaceRegExp(type, todo, offset: offset);
      case TransformationType.Substring:
        return _execSubstring(type, todo, offset: offset);
      case TransformationType.ToLowerCase:
      case TransformationType.ToUpperCase:
        return _execToCase(type, todo, offset: offset);
      default:
        return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execDateTime(TransformationType type, List<Object?> todo, {int offset = 0}) {
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
      case TransformationType.TimeNow:
        return nowStr.substring(11, 6);
      default:
        return nowStr;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execExecute(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var txt = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var cmd = Command(text: txt, isToVar: true);

    return cmd.exec();
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIndex(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var fndStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if ((inpStr != null) && inpStr.isEmpty &&
        (fndStr != null) && fndStr.isEmpty) {
      var begStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
      var begPos = _toInt(begStr) ?? 0;

      switch (type) {
        case TransformationType.Index:
          return inpStr.indexOf(fndStr, begPos).toString();
        case TransformationType.LastIndex:
          return inpStr.lastIndexOf(fndStr, begPos).toString();
        default:
          break;
      }
    }

    return '-1';
  }

  //////////////////////////////////////////////////////////////////////////////

  String? _execIndexRegExp(TransformationType type, List<Object?> todo, {int offset = 0}) {
    var cnt = todo.length;

    var inpStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
    var patStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());

    if ((inpStr != null) && inpStr.isNotEmpty &&
        (patStr != null) && patStr.isNotEmpty) {
      var flgStr = (cnt <= (++offset) ? null : exec(todo[offset])?.toString());
      var regExp = _toRegExp(patStr, flgStr);

      if (regExp != null) {
        switch (type) {
          case TransformationType.IndexRegExp:
            var match = regExp.firstMatch(inpStr);
            return (match?.start ?? -1).toString();
          case TransformationType.LastIndexRegExp:
            var allMatches = regExp.allMatches(inpStr);
            if (allMatches.isNotEmpty) {
              return allMatches.last.start.toString();
            }
            break;
          default:
            break;
        }
      }
    }

    return '-1';
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

  String? _execReplaceRegExp(TransformationType type, List<Object?> todo, {int offset = 0}) {
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
        resStr = inpStr.replaceAllMapped(regExp, (match) => _execReplaceRegExpMatcher(match, dstStr));
      }
      else {
        resStr = inpStr.replaceFirstMapped(regExp, (match) => _execReplaceRegExpMatcher(match, dstStr));
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

  String _execReplaceRegExpMatcher(Match match, String dstStr) {
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
      case TransformationType.ToLowerCase:
        return inpStr.toLowerCase();
      case TransformationType.ToUpperCase:
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
    nameTypeMap[_toName(keywords.forFnDiv)] = TransformationType.Div;
    nameTypeMap[_toName(keywords.forFnIndex)] = TransformationType.Index;
    nameTypeMap[_toName(keywords.forFnIndexRegExp)] = TransformationType.IndexRegExp;
    nameTypeMap[_toName(keywords.forFnLastIndex)] = TransformationType.LastIndex;
    nameTypeMap[_toName(keywords.forFnLastIndexRegExp)] = TransformationType.LastIndexRegExp;
    nameTypeMap[_toName(keywords.forFnLower)] = TransformationType.ToLowerCase;
    nameTypeMap[_toName(keywords.forFnMax)] = TransformationType.Max;
    nameTypeMap[_toName(keywords.forFnMin)] = TransformationType.Min;
    nameTypeMap[_toName(keywords.forFnMod)] = TransformationType.Mod;
    nameTypeMap[_toName(keywords.forFnMul)] = TransformationType.Mul;
    nameTypeMap[_toName(keywords.forFnNow)] = TransformationType.Now;
    nameTypeMap[_toName(keywords.forFnReplace)] = TransformationType.Replace;
    nameTypeMap[_toName(keywords.forFnReplaceRegExp)] = TransformationType.ReplaceRegExp;
    nameTypeMap[_toName(keywords.forFnRun)] = TransformationType.Run;
    nameTypeMap[_toName(keywords.forFnSub)] = TransformationType.Sub;
    nameTypeMap[_toName(keywords.forFnSubstr)] = TransformationType.Substring;
    nameTypeMap[_toName(keywords.forFnToday)] = TransformationType.Today;
    nameTypeMap[_toName(keywords.forFnTimeNow)] = TransformationType.TimeNow;
    nameTypeMap[_toName(keywords.forFnUpper)] = TransformationType.ToUpperCase;
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