import 'package:test/test.dart';
import 'package:xnx/command.dart';

import 'helper.dart';

/// Test entry point
///
void main() {
  var c = Command();

  Helper.forEachMemoryFileSystem((fs) {
    Helper.initFileSystem(fs);

    group('Command -', () {
      test('getStartCommandText', () {
        var startCmd = Command.getStartCommandText();
        expect(startCmd.isNotEmpty, true);
      });
    });
    group('Command - exec - ${fs.style} -', () {
      setUp(() {
        c = Command(isToVar: true);
      });
      test('null', () {
        expect(c.exec(newText: null), '');
      });
      test('empty', () {
        expect(c.exec(newText: ''), '');
      });
      test('internal', () {
        expect(c.exec(newText: '--print "1 2"'), '1 2');
      });
      test('external', () {
        expect(c.exec(newText: 'echo "1 2"', runInShell: true), '1 2');
      });
    });
  });
}

////////////////////////////////////////////////////////////////////////////////
