import 'package:test/test.dart';
import 'package:xnx/src/config.dart';
import 'package:xnx/src/operation.dart';

void main() {
  group('Operation', () {
    test('parse', () {
      var o = Operation(Config());

      expect(o.parse('').isAlwaysFalse, true);
      expect(o.parse('  ').isAlwaysFalse, true);
      expect(o.parse('!  ').isAlwaysTrue, true);
      expect(o.parse('0').isAlwaysFalse, true);
      expect(o.parse('!0').isAlwaysTrue && o.hasNegation, true);
      expect(o.parse(' 0 ').isAlwaysFalse, true);
      expect(o.parse('1').isAlwaysTrue, true);
      expect(o.parse('!  1').isAlwaysFalse && o.hasNegation, true);
      expect(o.parse(' 1 ').isAlwaysTrue, true);
      expect(o.parse('a').isAlwaysTrue, true);
      expect(o.parse(' a ').isAlwaysTrue, true);
      expect(o.parse(' false ').isAlwaysFalse, true);
      expect(o.parse(' !false ').isAlwaysTrue && o.hasNegation, true);
      expect(o.parse(' true ').isAlwaysTrue, true);
      expect(o.parse(' !true ').isAlwaysFalse && o.hasNegation, true);

      expect(!o.parse(' a > b').isNumeric && o.isCompare && o.isStrictCompare && !o.hasNegation, true);
      expect(!o.parse('a < b ').isNumeric && o.isCompare && o.isStrictCompare && !o.hasNegation, true);
      expect(!o.parse('a >= b').isNumeric && o.isCompare && !o.isStrictCompare && !o.hasNegation, true);
      expect(!o.parse('a <= b').isNumeric && o.isCompare && !o.isStrictCompare && !o.hasNegation, true);
      expect(!o.parse('a!> b').isNumeric && o.isCompare && !o.isStrictCompare && o.hasNegation, true);
      expect(!o.parse('a!<b').isNumeric && o.isCompare && !o.isStrictCompare && o.hasNegation, true);
      expect(!o.parse('a<=1').isNumeric && o.isCompare && !o.isStrictCompare && !o.hasNegation, true);
      expect(o.parse('0<=1').isNumeric && o.isCompare && !o.isStrictCompare && !o.hasNegation, true);

      expect(o.parse('a = b').isEquals && o.isCaseSensitive && !o.hasNegation, true);
      expect(o.parse('1 == 2').isEquals && o.isCaseSensitive && !o.hasNegation, true);
      expect(o.parse('aa != bbb').isEquals && o.isCaseSensitive && o.hasNegation, true);
      expect(o.parse('0 !== 1').isEquals && o.isCaseSensitive && o.hasNegation, true);
      expect(o.parse('ab =/i AB').isEquals && !o.isCaseSensitive && !o.hasNegation, true);
      expect(o.parse('ab ==/i AB').isEquals && !o.isCaseSensitive && !o.hasNegation, true);
      expect(o.parse('a !=/i ').isEquals && !o.isCaseSensitive && o.hasNegation, true);
      expect(o.parse('a !==/i B').isEquals && !o.isCaseSensitive && o.hasNegation, true);

      expect(o.parse('a~a').isMatches && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('aa=~a').isMatches && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('ab~=b').isMatches && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('Ab~/iB').isMatches && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a\nb~/m^[ab]\\\$').isMatches && o.isCaseSensitive && !o.isDotAll && o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a~/s b').isMatches && o.isCaseSensitive && o.isDotAll && !o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a~/u b').isMatches && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a~/is b').isMatches && !o.isCaseSensitive && o.isDotAll && !o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a~/mi b').isMatches && !o.isCaseSensitive && !o.isDotAll && o.isMultiLine && !o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a~/iu b').isMatches && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a~/misu b').isMatches && !o.isCaseSensitive && o.isDotAll && o.isMultiLine && o.isUnicode && !o.hasNegation, true);
      expect(o.parse('a!~/i').isMatches && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode && o.hasNegation, true);
      expect(o.parse('a!=~/i').isMatches && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode && o.hasNegation, true);
      expect(o.parse('a!~/u').isMatches && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode && o.hasNegation, true);
      expect(o.parse('a!~=/u').isMatches && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode && o.hasNegation, true);
      expect(o.parse('a!~/umsi').isMatches && !o.isCaseSensitive && o.isDotAll && o.isMultiLine && o.isUnicode && o.hasNegation, true);
    });

    test('exec', () {
      var o = Operation(Config());

      expect(o.exec(''), false);
      expect(o.exec('  '), false);
      expect(o.exec('0'), false);
      expect(o.exec(' 0 '), false);
      expect(o.exec('1'), true);
      expect(o.exec(' 1 '), true);
      expect(o.exec('a'), true);
      expect(o.exec(' a '), true);
      expect(o.exec(' false '), false);
      expect(o.exec(' true '), true);

      expect(o.exec('a > 1'), true);
      expect(o.exec('a  < 1'), false);
      expect(o.exec('0> 1'), false);
      expect(o.exec('1 >=0'), true);
      expect(o.exec('1<=0'), false);
      expect(o.exec('0<1'), true);
      expect(o.exec('"0!=1"  == "0!=1"'), true);
      expect(o.exec("'0!=1'  == '0!=1'"), true);
      expect(o.exec('"0!=1 " == "0!=1"'), false);
      expect(o.exec("'0!=1 ' == '0!=1'"), false);

      expect(o.exec('aa != bbb'), true);
      expect(o.exec('0 !== 1'), true);
      expect(o.exec('ab =/i AB'), true);
      expect(o.exec('ab ==/i AB'), true);
      expect(o.exec('a !=/i '), true);
      expect(o.exec('a !==/i B'), true);

      expect(o.exec('a~a'), true);
      expect(o.exec('aa=~a'), true);
      expect(o.exec('ab~=b'), true);
      expect(o.exec('Ab~/iB'), true);
      expect(o.exec('a\nb~/m^[ab]\\\$'), false);
      expect(o.exec('a\nb~/m^[ab]\$'), true);
      expect(o.exec('a~/s b'), false);
      expect(o.exec('a~/u a'), true);
      expect(o.exec('a\na~/im a.a'), false);
      expect(o.exec('a\na~/is a.a'), true);
      expect(o.exec('a~/mi b'), false);
      expect(o.exec('\uFFFF~/iu \uFFFF'), true);
      expect(o.exec('\uFFFF~/misu \uFFFF'), true);
      expect(o.exec('a!~/i'), true);
      expect(o.exec('a!=~/i'), true);
      expect(o.exec('a!~/u'), true);
      expect(o.exec('a!~=/u'), true);
      expect(o.exec('a!~/umsi'), true);
    });
  });
}
