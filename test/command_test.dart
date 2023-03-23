import 'package:test/test.dart';
import 'package:xnx/command.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';

import 'helper.dart';

/// Test entry point
///
void main() {
  var c = Command();
  final cmdShell = Env.getShell();
  final isWin = Env.isWindows;

  Helper.forEachMemoryFileSystem((fs) {
    Helper.initFileSystem(fs);

    group('Command -', () {
      test('getStartCommand', () {
        var startCmd = Command.getStartCommand();
        expect(startCmd.isNotEmpty, true);
      });
    });
    group('Command - parse - ${fs.style} -', () {
      test('null', () {
        c.split(null);
        expect([c.path, c.args], ['', []]);
      });
      test('empty', () {
        c.split('');
        expect([c.path, c.args], ['', []]);
      });
      test('single', () {
        c.split('abc');
        expect([c.path, c.args], ['abc', []]);
      });
      test('plain', () {
        c.split('abc def ghi');
        expect([c.path, c.args], ['abc', ['def', 'ghi']]);
      });
      test('quotes', () {
        c.split('"abc" "d\'e\'f" \'g"hi"\'');
        expect([c.path, c.args], ['abc', ['d\'e\'f', 'g"hi"']]);
      });
      test('quotes and spaces', () {
        c.split('"ab c" "d \'e\' f" \'g  "hi"\'');
        expect([c.path, c.args], ['ab c', ['d \'e\' f', 'g  "hi"']]);
      });
      test('pipe (no space around)', () {
        c.split('abc def|ghi');
        expect([c.path, c.args.length], [cmdShell, (isWin ? 4 : 2)]);
      });
      test('pipe (with spaces around)', () {
        c.split('abc def | ghi');
        expect([c.path, c.args.length], [cmdShell, (isWin ? 4 : 2)]);
      });
      test('redirect', () {
        c.split('abc def > ghi');
        expect([c.path, c.args.length], [cmdShell, (isWin ? 4 : 2)]);
      });
      test('escaped pipe (backtick)', () {
        c.split('abc def`| ghi');
        expect([c.path, c.args.length], [cmdShell, (isWin ? 4 : 2)]);
      });
      test('non-escaped pipe (backslash)', () {
        c.split('abc def\\| ghi');
        expect([c.path, c.args.length], [cmdShell, (isWin ? 4 : 2)]);
      });
      test('escaped escape', () {
        c.split('abc def``| ghi');
        expect([c.path, c.args.length], [cmdShell, (isWin ? 4 : 2)]);
      });
      test('Windows path', () {
        c.split('"C:\\Program Files\\Company\\a.exe" "\\a b\\c d\\e.txt"');
        final e = (Path.isWindowsFS ? '\\' : '');
        expect([c.path, c.args], ['C:${e}Program Files${e}Company${e}a.exe', ['${e}a b${e}c d${e}e.txt']]);
      });
      test('escape resolved', () {
        final e = Env.escape;
        c.split('abc def${e}t${e}r${e}n');
        expect(c.args[0], 'deftrn');
      });
      test('escape resolved in a literal string', () {
        final e = Env.escape;
        c.split("abc 'def${e}t${e}r${e}n'");
        expect(c.args[0], 'deftrn');
      });
      test('a mix of quotes', () {
        c.split('abc \'"d e f"\'');
        expect(c.args[0], '"d e f"');
      });
      test('backslashes in a literal string', () {
        c.split(r'abc "\\\d e f"');
        expect(c.args[0], r'\\\d e f');
      });
      test('quoted option arg', () {
        c.split(r'--inp="a/b.txt" c -d');
        expect(((c.args[0] == r'--inp="a/b.txt"') && (c.args[1] == 'c')), true);
      });
    });
    group('Command - exec - ${fs.style} -', () {
      setUp(() {
        c = Command(isToVar: true);
      });
      test('null', () {
        expect(c.exec(text: null), '');
      });
      test('empty', () {
        expect(c.exec(text: ''), '');
      });
      test('internal', () {
        expect(c.exec(text: '--print "1 2"'), '1 2');
      });
      test('external', () {
        if (!isWin) {
          expect(c.exec(text: '"${Env.getShell()}" echo "1 2"'), '1 2');
        }
      });
    });
  });
}

////////////////////////////////////////////////////////////////////////////////
