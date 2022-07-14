import 'package:test/test.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/options.dart';

import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Options', () {
      test('parseArgs', () {
        Helper.initFileSystem(fileSystem);

        var o = Options();

        expect(() => o.parseArgs(['-p', '6', '-q',]), throwsException);
        expect(o.compression, 6);
        expect(o.configFileInfo.filePath.isEmpty, true);

        var configFile = Path.fileSystem.file('a.xnx')..createSync();

        o.parseArgs(['-p', '6', '-q', '--xnx', 'a']);
        expect(Path.equals(o.configFileInfo.filePath, Path.join(Path.currentDirectory.path, 'a.xnx')), true);
        expect(Env.get('_XNX_COMPRESSION'), '6');

        o.parseArgs(['-p', '7', '-q', '--xnx', 'a']);
        expect(o.compression, 7);

        o.parseArgs(['-q', '-c', 'a', '--xnx', 'a']);
        expect(o.compression, 7);

        configFile.deleteSync();
      });
      test('setConfigPathAndStartDirName', () {
        Helper.initFileSystem(fileSystem);

        var o = Options();

        var initDirName = Path.currentDirectory.path;
        var baseName = 'a.xnx';
        var configPath = Path.join(initDirName, baseName);

        var configFile = Path.fileSystem.file(configPath)..createSync();

        Path.fileSystem.currentDirectory = initDirName;
        o.setConfigPathAndStartDirName(null, null);
        expect(Path.equals(o.configFileInfo.filePath, Path.join(initDirName, baseName)), true);
        expect(Path.equals(Path.currentDirectory.path, initDirName), true);

        configFile.deleteSync();

        var dirName = Path.join(initDirName, 'sub');
        configPath = Path.join(dirName, baseName);
        configFile = Path.fileSystem.file(configPath)..createSync(recursive: true);

        Path.fileSystem.currentDirectory = initDirName;
        o.setConfigPathAndStartDirName(configPath, null);
        expect(Path.equals(o.configFileInfo.filePath, Path.join(dirName, baseName)), true);
        expect(Path.equals(Path.currentDirectory.path, initDirName), true);

        Path.fileSystem.currentDirectory = initDirName;
        o.setConfigPathAndStartDirName(configPath, '~');
        expect(Path.equals(o.configFileInfo.filePath, Path.join(dirName, baseName)), true);
        expect(Path.equals(Path.currentDirectory.path, dirName), true);

        Path.fileSystem.currentDirectory = initDirName;
        o.setConfigPathAndStartDirName('~${Path.basename(configPath)}', Path.dirname(configPath));
        expect(Path.equals(o.configFileInfo.filePath, Path.join(dirName, baseName)), true);
        expect(Path.equals(Path.currentDirectory.path, dirName), true);
      });
    });
  });
}
