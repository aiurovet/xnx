class RegExpEx {
  static final RegExp _rexGroup = RegExp(r'(\\\\)|(\\\$)|(\$([\d]+))|\$\{([\d]+)\}');

  RegExp regExp;
  bool isGlobal = false;

  RegExpEx(this.regExp, this.isGlobal);

  static RegExpEx? fromDecoratedPattern(String pattern, {String? prefix, String? suffix}) {
    var prefixLen = prefix?.length ?? 0;

    if ((prefixLen > 0) && (prefix != null) && pattern.startsWith(prefix)) {
      var keyLen = pattern.length;
      var endPatPos = ((suffix?.isEmpty ?? true) || (suffix  == null) ? keyLen : pattern.lastIndexOf(suffix));

      if (endPatPos == 0) {
        endPatPos = keyLen;
      }

      var actualPattern = pattern.substring(prefixLen, endPatPos);
      var flags = '';

      if ((++endPatPos) < keyLen) {
        flags = pattern.substring(endPatPos);
      }

      return fromPattern(actualPattern, flags: flags);
    }

    return null;
  }

  static RegExpEx? fromPattern(String? pattern, {String? flags}) {
    if (pattern == null) {
      return null;
    }

    flags ??= '';

    return RegExpEx(
      RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      ),
      flags.contains('g'),
    );
  }

  String replace(String inpStr, String dstStr) {
    String resStr;

    if (dstStr.contains(r'$')) {
      if (isGlobal) {
        resStr = inpStr.replaceAllMapped(regExp, (match) => _replaceMatchProc(match, dstStr));
      }
      else {
        resStr = inpStr.replaceFirstMapped(regExp, (match) => _replaceMatchProc(match, dstStr));
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

  String _replaceMatchProc(Match match, String dstStr) {
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
      var groupNo = (s == null ? -1 : int.tryParse(s) ?? -1);

      if ((groupNo >= 0) && (groupNo <= match.groupCount)) {
        return match[groupNo] ?? '';
      }
      else {
        return '';
      }
    });
  }
}