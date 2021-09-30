import 'dart:io';
import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/string.dart';
import '../helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    Env.init(fileSystem);

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
        expect(Env.expand('a \$XNX_A \$XNX_B\x01 \$#\$1 \$2 \$\$XNX_C \$ d', args: [ 'a1', 'a2' ]), 'a A B\x01 2a1 a2 \$XNX_C \$ d');
      });

      test('get', () {
        expect(Env.get(Env.homeKey), Platform.environment[Env.homeKey]);
        expect(Env.get(Env.homeKey.toLowerCase()), Env.isWindows ? Platform.environment[Env.homeKey] : StringExt.EMPTY);
      });

      test('getAll', () {
        Env.clearLocal();
        expect(Env.getAll().length, Platform.environment.length);
        Env.set('XNX_A', 'A');
        expect(Env.getAll().length, Platform.environment.length + 1);
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
        expect(Env.getHome(), Platform.environment[Env.isWindows ? 'USERPROFLE' : 'HOME']);
      });

      test('homeKey', () {
        expect(Env.homeKey, (Env.isWindows ? 'USERPROFLE' : 'HOME'));
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
        expect(() => Env.set(Env.homeKey, 'A'), throwsException);
      });
    });
  });
}
