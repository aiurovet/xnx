import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/options.dart';

import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Options', () {
      test('parseArgs', () {
        Helper.initFileSystem(fileSystem);

        var o = Options();
        o.parseArgs(['-p', '6', '-q']);
        expect(o.compression, 6);
        expect(o.configFileInfo.filePath.isEmpty, true);

        Path.fileSystem.file('a.xnx').createSync();

        o.parseArgs(['-p', '6', '-q', '--config', 'a']);
        expect(o.configFileInfo.filePath, Path.getFullPath('a.xnx'));
        expect(Env.get('_XNX_COMPRESSION'), '6');

        o.parseArgs(['-p', '7', '-q', '--config', 'a']);
        expect(o.compression, 7);

        o.parseArgs(['-q', '--config', 'a']);
        expect(o.compression, 7);
      });
    });
  });
}
