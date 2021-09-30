import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';
import 'package:xnx/src/config.dart';
import 'package:xnx/src/expression.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';

import 'helper.dart';

////////////////////////////////////////////////////////////////////////////////

final blockThen = [true];
final blockElse = [false];

final keyIf = '{{-if-}}';
final keyCondition = '';

////////////////////////////////////////////////////////////////////////////////

var mapIf = { keyIf: {
  keyCondition: 'false',
  '{{-then-}}': blockThen,
  '{{-else-}}': blockElse
}};

////////////////////////////////////////////////////////////////////////////////

void init(FileSystem fileSystem) {
  Env.init(fileSystem);

  var root = (Env.fileSystem is MemoryFileSystem ? Path.getFullPath(Path.separator) : Env.getHome());
  var path = Path.join(root, 'test-dir', 'sub-dir');
  var dir = Env.fileSystem.directory(path);

  dir.createSync(recursive: true);

  Env.fileSystem.file(Path.join(path, 'file1.txt')).createSync();
  Env.fileSystem.file(Path.join(path, 'file2.txt')).createSync();
}

////////////////////////////////////////////////////////////////////////////////

void main() {
  group('Expression', () {
    Helper.forEachMemoryFileSystem((fileSystem) {
      test('exec', () {
        init(fileSystem);

        var x = Expression(FlatMap(), Keywords());

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

Map<String, Object> setIf(String? condition) {
  var dataIf = mapIf[keyIf];

  (dataIf as Map<String, Object?>)[keyCondition] = condition;

  if (dataIf == null) {
    throw Exception('Conditional map should not be null');
  }

  return dataIf;
}

////////////////////////////////////////////////////////////////////////////////
