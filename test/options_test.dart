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

        expect(
            () => o.parseArgs([
                  '-p',
                  '6',
                  '-q',
                ]),
            throwsException);
        expect(o.compression, 6);
        expect(o.configFileInfo.filePath.isEmpty, true);

        var configFile = Path.fileSystem.file('a.xnx')..createSync();

        o.parseArgs(['-p', '6', '-q', '--xnx', 'a']);
        expect(
            Path.equals(o.configFileInfo.filePath,
                Path.join(Path.currentDirectoryName, 'a.xnx')),
            true);
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

        var initDirName = Path.currentDirectoryName;
        var baseName = 'a.xnx';
        var configPath = Path.join(initDirName, baseName);

        var configFile = Path.fileSystem.file(configPath)..createSync();

        Path.currentDirectoryName = initDirName;
        o.setConfigPathAndStartDirName(null, null);
        expect(
            Path.equals(
                o.configFileInfo.filePath, Path.join(initDirName, baseName)),
            true);
        expect(Path.equals(Path.currentDirectoryName, initDirName), true);

        configFile.deleteSync();

        var dirName = Path.join(initDirName, 'sub');
        configPath = Path.join(dirName, baseName);
        configFile = Path.fileSystem.file(configPath)
          ..createSync(recursive: true);

        Path.currentDirectoryName = initDirName;
        o.setConfigPathAndStartDirName(configPath, null);
        expect(
            Path.equals(
                o.configFileInfo.filePath, Path.join(dirName, baseName)),
            true);
        expect(Path.equals(Path.currentDirectoryName, initDirName), true);

        Path.currentDirectoryName = initDirName;
        o.setConfigPathAndStartDirName(configPath, '~');
        expect(
            Path.equals(
                o.configFileInfo.filePath, Path.join(dirName, baseName)),
            true);
        expect(Path.equals(Path.currentDirectoryName, initDirName), true);

        Path.currentDirectoryName = initDirName;
        o.setConfigPathAndStartDirName(configPath, dirName);
        expect(
            Path.equals(
                o.configFileInfo.filePath, Path.join(dirName, baseName)),
            true);
        expect(Path.equals(Path.currentDirectoryName, dirName), true);

        Path.currentDirectoryName = initDirName;
        o.setConfigPathAndStartDirName(
            '~${Path.basename(configPath)}', Path.dirname(configPath));
        expect(
            Path.equals(
                o.configFileInfo.filePath, Path.join(initDirName, baseName)),
            true);
        expect(Path.equals(Path.currentDirectoryName, dirName), true);
      });
      test('setCmdStartDirName', () {
        Helper.initFileSystem(fileSystem);

        var o = Options();

        var dirName = Path.currentDirectoryName;

        o.setCmdStartDirName(null);
        expect(Path.equals(Path.currentDirectoryName, dirName), true);

        Path.join(dirName, 'sub');
        Path.fileSystem.directory(dirName).createSync(recursive: true);

        o.setCmdStartDirName(dirName);
        expect(Path.equals(Path.currentDirectoryName, dirName), true);
      });
    });
  });
}
