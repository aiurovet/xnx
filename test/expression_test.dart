import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:xnx/expression.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/flat_map.dart';
import 'package:xnx/keywords.dart';
import 'package:xnx/logger.dart';
import 'package:xnx/operation.dart';

import 'helper.dart';

////////////////////////////////////////////////////////////////////////////////

final blockThen = [true];
final blockElse = [false];

final keywords = Keywords();

////////////////////////////////////////////////////////////////////////////////

void init(FileSystem fileSystem) {
  Helper.initFileSystem(fileSystem);

  var root = (Path.fileSystem is MemoryFileSystem ? Path.getFullPath(Path.separator) : Env.getHome());
  var path = Path.join(root, 'test-dir', 'sub-dir');
  var dir = Path.fileSystem.directory(path);

  dir.createSync(recursive: true);

  Path.fileSystem.file(Path.join(path, 'file1.txt')).createSync();
  Path.fileSystem.file(Path.join(path, 'file2.txt')).createSync();
}

////////////////////////////////////////////////////////////////////////////////

void main() {
  group('Expression', () {
    Helper.forEachMemoryFileSystem((fileSystem) {
      test('exec', () {
        init(fileSystem);

        var flatMap = FlatMap();
        var logger = Logger();
        var x = Expression(flatMap: flatMap, keywords: Keywords(), operation: Operation(flatMap: flatMap, logger: logger), logger: logger);

        expect(x.exec(setIf('false')), blockElse);
        expect(x.exec(setIf('true')), blockThen);
        expect(x.exec(setIf('!false')), blockThen);
        expect(x.exec(setIf(' !  true')), blockElse);
        expect(x.exec(setIf(' !  !\t\t! false')), blockThen);
        expect(x.exec(setIf('true || false')), blockThen);
        expect(x.exec(setIf('true && false')), blockElse);
        expect(x.exec(setIf('(true && false) || (true && !false)')), blockThen);
        expect(x.exec(setIf('(!true || false) && (true || false)')), blockElse);
        expect(x.exec(setIf('-e/test-dir')), blockThen);
        expect(x.exec(setIf(' ! -d /test-dir/sub-dir')), blockElse);
        expect(x.exec(setIf('-f /test-dir/sub-dir/*1.txt')), blockThen);
        expect(x.exec(setIf('-e /test-dir/**/*2.txt')), blockThen);
        expect(x.exec(setIf('""AU"" ~ "^("AU"|US)\$"')), blockThen);
        expect(x.exec(setIf(Env.getHome())), blockThen); // a string test
      });
    });
  });
}

////////////////////////////////////////////////////////////////////////////////

Map<String, Object?> setIf(String condition) {
  return {
    condition: blockThen,
    keywords.forElse: blockElse,
  };
}

////////////////////////////////////////////////////////////////////////////////
