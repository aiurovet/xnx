import 'dart:io';
import 'package:test/test.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    Helper.initFileSystem(fileSystem);

    group('Environment', () {
      test('clearLocal', () {
        Env.clearLocal();
        expect(Env.getAllLocal().length, 0);
        Env.set('XNX_A', 'A');
        expect(Env.getAllLocal().length, 1);
        Env.clearLocal();
        expect(Env.getAllLocal().length, 0);
      });

      test('expand', () {
        Env.clearLocal();
        Env.set('XNX_A', 'A');
        Env.set('XNX_B', 'B');
        expect(Env.expand('a \$XNX_A \$XNX_B \$XNX_C d'), 'a A B  d');
        expect(Env.expand('a \$XNX_A \$XNX_B\x01 \$#\$~1 \$~2 \\\$XNX_C \\\$ d', args: [ 'a1', 'a2' ]), 'a A B\x01 2a1 a2 \$XNX_C \$ d');
        expect(Env.expand('a \${Y:-\${Z:=\${XNX_A}}} b \${XNX_B}'), 'a A b B');
        expect(Env.expand('a \$#XNX_A b \${#XNX_B}'), 'a 1 b 1');
        expect(Env.expand('a \$#~1 b \${#~2} \${3:-No #3}', args: [ 'a1', 'ab2' ]), 'a 2 b 3 No #3');
        expect(Env.expand('a \$@ \$~* \${#~@}', args: [ 'a1', 'a2', 'a 3' ]), 'a a1 a2 "a 3" a1 a2 "a 3" 11');
        expect(Env.expand('a \$@@ \${**}', args: [ 'a1', 'a2' ]), 'a a1 a2@ ');
      });

      test('get', () {
        expect(Env.get(Env.homeKey), Platform.environment[Env.homeKey]);
        expect(Env.get(Env.homeKey.toLowerCase()), Env.isWindows ? Platform.environment[Env.homeKey] : '');
      });

      test('getAll', () {
        Env.clearLocal();
        expect(Env.getAll().length, Platform.environment.length);
        Env.set('XNX_A', 'A');
        expect(Env.getAll().length, Platform.environment.length + 1);

        Env.set(Env.homeKey, 'A');
        var fullEnv = Env.getAll();
        expect(fullEnv[Env.homeKey], 'A');
      });

      test('getAllLocal', () {
        Env.clearLocal();
        expect(Env.getAllLocal().length, 0);
        Env.set('XNX_A', 'A');
        expect(Env.getAllLocal().length, 1);
        Env.set('XNX_B', 'B');
        expect(Env.getAllLocal().length, 2);
        Env.set('XNX_A', 'C');
        expect(Env.getAllLocal().length, 2);
      });

      test('getHome', () {
        expect(Env.getHome(), Platform.environment[Env.isWindows ? 'USERPROFILE' : 'HOME']);
      });
      test('homeKey', () {
        expect(Env.homeKey, (Env.isWindows ? 'USERPROFILE' : 'HOME'));
      });
      test('isShell', () {
        final shellNames = <String>['ash'];
        expect([
          Env.isShell(null, shellNames),
          Env.isShell('', shellNames),
          Env.isShell('ash', shellNames),
          Env.isShell('aash', shellNames),
          Env.isShell('ashh', shellNames),
          Env.isShell('ash.exe', shellNames),
          Env.isShell('abc${Path.separator}ash', shellNames),
          Env.isShell('abc${Path.separator}ash.com', shellNames),
        ], [false, false, true, false, false, Env.isWindows, true, Env.isWindows]);
      });
      test('set', () {
        Env.clearLocal();
        Env.set('XNX_A', 'A');
        expect(Env.get('XNX_A'), 'A');
        Env.set('XNX_B', 'B');
        Env.set('XNX_A', 'C');
        expect(Env.get('XNX_A'), 'C');
        Env.set('Xnx_A', 'A');
        expect(Env.get('XNX_A'), Env.isWindows ? 'A' : 'C');
        Env.set(Env.homeKey, 'A');
        expect(Env.get(Env.homeKey), 'A');
      });
      test('which', () {
        expect(Env.which('').isEmpty, true);
        expect(Env.which(Env.isWindows ? 'xcopy' : 'ls').isEmpty, true);
      });
    });
  });
}
