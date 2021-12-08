import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:xnx/src/expression.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/operation.dart';

import 'helper.dart';

////////////////////////////////////////////////////////////////////////////////

final blockThen = [true];
final blockElse = [false];

final keywords = Keywords();
final keyIf = keywords.forIf;
final keyCondition = '';


////////////////////////////////////////////////////////////////////////////////

var mapIf = { keywords.forIf: {
  keyCondition: 'false',
  keywords.forThen: blockThen,
  keywords.forElse: blockElse
}};

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
        expect(x.exec(setIf(Env.getHome())), blockThen); // a string test
      });
    });
  });
}

////////////////////////////////////////////////////////////////////////////////

Map<String, Object?> setIf(String? condition) {
  var dataIf = mapIf[keyIf];

  (dataIf as Map<String, Object?>)[keyCondition] = condition;

  if (dataIf == null) {
    throw Exception('Conditional map should not be null');
  }

  return dataIf;
}

////////////////////////////////////////////////////////////////////////////////
