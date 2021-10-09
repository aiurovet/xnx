import 'package:test/test.dart';
import 'package:xnx/src/command.dart';
import 'package:xnx/src/ext/env.dart';

void main() {
  group('Command', () {
    test('getStartCommand', () {
      var startCmd = Command.getStartCommand();
      expect(startCmd.isNotEmpty, true);
    });
    test('parse', () {
      var c = Command();

      expect(c.parse(null).path.isEmpty && c.args.isEmpty, true);
      expect(c.parse('').path.isEmpty && c.args.isEmpty, true);
      expect((c.parse('abc').path.length == 3) && c.args.isEmpty, true);
      expect((c.parse('abc def ghi').path.length == 3) && (c.args.length == 2), true);
      expect((c.parse('"abc" "d\'e\'f" \'g"hi"\'').path.length == 3) && (c.args.length == 2), true);
      expect((c.parse('"ab c" "d \'e\' f" \'g  "hi"\'').path.length == 4) && (c.args.length == 2), true);
      expect((c.parse('abc def|ghi').path.length == 3) && (c.args.length == 3), true);
      expect((c.parse('abc def| ghi').path.length == 3) && (c.args.length == 3), true);
      expect((c.parse('abc def\\| ghi').path.length == 3) && (c.args.length == 2), true);
      expect(c.parse('abc def\\t\\r\\n').args[0].endsWith('\t\r\n'), true);
      expect(c.parse('abc \'"d e f"\'').args[0], '"d e f"');
      expect(c.parse('abc "\\\\\\"d e f\\""').args[0], '\\"d e f"');
    });

    test('exec', () {
      Env.init();

      var c = Command(isToVar: true);

      expect(c.exec(text: null), '');
      expect(c.exec(text: ''), '');
      expect(c.exec(text: '--print "1 2"'), '1 2');

      if (!Env.isWindows) {
        expect(c.exec(text: 'echo "1 2"'), '1 2');
      }
    });
  });
}

////////////////////////////////////////////////////////////////////////////////
