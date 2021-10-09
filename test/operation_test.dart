import 'package:test/test.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/operation.dart';

void main() {
  group('Operation', () {
    test('parse', () {
      var o = Operation(flatMap: FlatMap());

      expect(o.parse(''), OperationType.AlwaysFalse);
      expect(o.parse('  '), OperationType.AlwaysFalse);
      expect(o.parse('!  '), OperationType.AlwaysTrue);
      expect(o.parse('!! \t!  '), OperationType.AlwaysTrue);
      expect(o.parse('0'), OperationType.AlwaysFalse);
      expect(o.parse('!0'), OperationType.AlwaysTrue);
      expect(o.parse(' 0 '), OperationType.AlwaysFalse);
      expect(o.parse('1'), OperationType.AlwaysTrue);
      expect(o.parse('!  1'), OperationType.AlwaysFalse);
      expect(o.parse(' 1 '), OperationType.AlwaysTrue);
      expect(o.parse('a'), OperationType.AlwaysTrue);
      expect(o.parse(' a '), OperationType.AlwaysTrue);
      expect(o.parse(' false '), OperationType.AlwaysFalse);
      expect(o.parse(' !false '), OperationType.AlwaysTrue);
      expect(o.parse(' true '), OperationType.AlwaysTrue);
      expect(o.parse(' !true '), OperationType.AlwaysFalse);

      expect(o.parse(' a > b'), OperationType.Greater);
      expect(o.parse('a < b '), OperationType.Less);
      expect(o.parse('a >= b'), OperationType.GreaterOrEquals);
      expect(o.parse('a <= b'), OperationType.LessOrEquals);
      expect(o.parse('a!> b'), OperationType.LessOrEquals);
      expect(o.parse('a!<b'), OperationType.GreaterOrEquals);
      expect(o.parse('a<=1'), OperationType.LessOrEquals);
      expect(o.parse('0>=1'), OperationType.GreaterOrEquals);

      expect(o.parse('a = b'), OperationType.Equals);
      expect(o.parse('1 == 2'), OperationType.Equals);
      expect(o.parse('aa != bbb'), OperationType.NotEquals);;
      expect(o.parse('0 !== 1'), OperationType.NotEquals);;
      expect((o.parse('ab =/i AB') == OperationType.Equals) && !o.isCaseSensitive, true);
      expect((o.parse('ab ==/i AB') == OperationType.Equals) && !o.isCaseSensitive, true);
      expect((o.parse('a !=/i ') == OperationType.NotEquals) && !o.isCaseSensitive, true);
      expect((o.parse('a !==/i B') == OperationType.NotEquals) && !o.isCaseSensitive, true);

      expect((o.parse('a~a') == OperationType.Matches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('ab~b') == OperationType.Matches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('Ab~/iB') == OperationType.Matches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a\nb~/m^[ab]\\\$') == OperationType.Matches) && o.isCaseSensitive && !o.isDotAll && o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/s b') == OperationType.Matches) && o.isCaseSensitive && o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/u b') == OperationType.Matches)  && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a~/is b') == OperationType.Matches) && !o.isCaseSensitive && o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/mi b') == OperationType.Matches) && !o.isCaseSensitive && !o.isDotAll && o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a~/iu b') == OperationType.Matches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a~/misu b') == OperationType.Matches) && !o.isCaseSensitive && o.isDotAll && o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a!~/i') == OperationType.NotMatches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a!~/i') == OperationType.NotMatches) && !o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && !o.isUnicode, true);
      expect((o.parse('a!~/u') == OperationType.NotMatches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a!~/u') == OperationType.NotMatches) && o.isCaseSensitive && !o.isDotAll && !o.isMultiLine && o.isUnicode, true);
      expect((o.parse('a!~/umsi') == OperationType.NotMatches) && !o.isCaseSensitive && o.isDotAll && o.isMultiLine && o.isUnicode, true);
    });

    test('exec', () {
      var o = Operation(flatMap: FlatMap());

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
      expect(o.exec('aa~a'), true);
      expect(o.exec('ab~b'), true);
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
      expect(o.exec('a!~/i'), true);
      expect(o.exec('a!~/u'), true);
      expect(o.exec('a!~/umsi'), true);
    });
  });
}
