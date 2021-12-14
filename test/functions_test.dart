import 'dart:math';

import 'package:test/test.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/file_oper.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/functions.dart';
import 'package:xnx/src/logger.dart';

import 'helper.dart';

void main() {
  group('Functions', () {
    test('execNonFile', () {
      Env.init();

      var flatMap = FlatMap();

      var logger = Logger();
      var now = DateTime.now();
      var nowStr = now.toIso8601String();
      var todayStr = nowStr.substring(0, 10);
      var cmdEcho = (Env.isWindows ? 'cmd /c echo' : 'echo');

      Functions(flatMap: flatMap, keywords: Keywords(), logger: logger)
        .exec(<String, Object?>{
          '{1+2}': [r'=add', 1, 2],
          '{4*3}': [r'=mul', 4, 3],
          '{math}': [r'=pow', [r'=mul', [r'=idiv', 9, 3], [r'=mod', 5, 3]], 2],
          '{cos}': [r'=Cos', ['=div', ['=Pi'], 3]],
          '{exp}': [r'=Exp', 1],
          '{pi}': ['=Pi'],
          '{rad}': ['=Rad', 90],
          '{round}': ['=Round', 1.617, 2, ],
          '{sin}': [r'=Sin', ['=div', ['=Pi'], 6]],
          '{sqrt}': [r'=Sqrt', 25],
          '{tan}': [r'=Tan', ['=div', ['=Pi'], 4]],
          '{ln}': [r'=Ln', exp(1)],
          '{today}': [r'=Today'],
          '{startOfMonth}': [r'=StartOfMonth', '2021-03-15'],
          '{endOfFeb}': [r'=EndOfMonth', '2021-02-15'],
          '{endOfMonth}': [r'=EndOfMonth', '2021-03-15'],
          '{year}': [r'=Today', 'yyyy'],
          '{date}': [r'=Date', '2021-03-15 14:27:35.080' ],
          '{time}': [r'=Time', '2021-03-15 14:27:35.080' ],
          '{local}': [r'=Local', '2021-03-15 14:27:35.080' ],
          '{utc}': [r'=Utc', '2021-03-15 14:27:35.080' ],
          '{date+2d}': [r'=AddDays', '2021-03-15', 2 ],
          '{date-2d}': [r'=AddDays', '2021-03-15', -2 ],
          '{date+2m}': [r'=AddMonths', '2021-03-15', 2 ],
          '{date-2m}': [r'=AddMonths', '2021-03-15', -2 ],
          '{date+2y}': [r'=AddYears', '2021-03-15', 2 ],
          '{date-2y}': [r'=AddYears', '2021-03-15', -2 ],
          '{today+2y}': [r'=AddYears', null, 2 ],
          '{Env}': 'DeV',
          '{env}': [r'=lower', '{Env}'],
          '{ENV}': [r'=Upper', '{Env}'],
          '{ENV,1,1}': [r'=Upper', ['=substr', '{env}', 1, 1]],
          '{env,3,1}': [r'=Lower', ['=substr', '{ENV}', 3, 1]],
          '{index5}': [r'=Index', 'Abcbcdefbqpr', 'b', 5],
          '{lastIndex}': [r'=LastIndex', 'Abcbcdefbqprstbz', 'b'],
          '{lastIndex14}': [r'=LastIndex', 'Abcbcdefbqprstbz', 'b', 14],
          '{match}': [r'=Match', 'Abcbcdefbqprcde', '[cd]'],
          '{lastMatch}': [r'=LastMatch', 'Abcbcdefbqprcde', '[cd]'],
          '{weird}': [r'=replaceMatch', '{Env}elop', '[de]', 'ab', '/gi'],
          '{groups}': [r'=replaceMatch', 'abcdefghi', '(bc(d))|(g(h))', r'$2\$2\\${4}', '/gi'],
          '{echo}': [r'=run', '$cmdEcho 1 2'],
        });

      expect(flatMap['{1+2}'], '3');
      expect(flatMap['{4*3}'], '12');
      expect(flatMap['{math}'], '36');
      expect((num.parse(flatMap['{cos}']    ?? '') * 10000).round(),  5000);
      expect((num.parse(flatMap['{exp}']    ?? '') * 10000).round(), 27183);
      expect((num.parse(flatMap['{ln}']     ?? '') * 10000).round(), 10000);
      expect((num.parse(flatMap['{pi}']     ?? '') * 10000).round(), 31416);
      expect((num.parse(flatMap['{rad}']    ?? '') * 10000).round(), 15708);
      expect((num.parse(flatMap['{round}']  ?? '') * 10000).round(), 16200);
      expect((num.parse(flatMap['{sin}']    ?? '') * 10000).round(),  5000);
      expect((num.parse(flatMap['{sqrt}']   ?? '') * 10000).round(), 50000);
      expect((num.parse(flatMap['{tan}']    ?? '') * 10000).round(), 10000);
      expect(flatMap['{today}'], todayStr);
      expect(flatMap['{year}'], todayStr.substring(0, 4));
      expect(flatMap['{startOfMonth}'], '2021-03-01');
      expect(flatMap['{endOfMonth}'], '2021-03-31');
      expect(flatMap['{endOfFeb}'], '2021-02-28');
      expect(flatMap['{date}'], '2021-03-15');
      expect(flatMap['{time}'], '14:27:35.080');
      expect(flatMap['{local}'], (DateTime.parse('2021-03-15T14:27:35.080').toUtc()).toLocal().toIso8601String());
      expect(flatMap['{utc}'], DateTime.parse('2021-03-15T14:27:35.080').toUtc().toIso8601String());
      expect(flatMap['{date+2d}'], '2021-03-17');
      expect(flatMap['{date-2d}'], '2021-03-13');
      expect(flatMap['{date+2m}'], '2021-05-15');
      expect(flatMap['{date-2m}'], '2021-01-15');
      expect(flatMap['{date+2y}'], '2023-03-15');
      expect(flatMap['{date-2y}'], '2019-03-15');
      expect(flatMap['{env}'], 'dev');
      expect(flatMap['{ENV}'], 'DEV');
      expect(flatMap['{ENV,1,1}'], 'D');
      expect(flatMap['{env,3,1}'], 'v');
      expect(flatMap['{index5}'], '9');
      expect(flatMap['{lastIndex}'], '15');
      expect(flatMap['{lastIndex14}'], '9');
      expect(flatMap['{match}'], '3');
      expect(flatMap['{lastMatch}'], '14');
      expect(flatMap['{weird}'], 'ababVablop');
      expect(flatMap['{groups}'], r'ad$2\ef$2\hi');
      expect(flatMap['{echo}'], '1 2');
    });
    test('execFile', () {
      Helper.forEachMemoryFileSystem((fileSystem) {
        Helper.initFileSystem(fileSystem);

        var logger = Logger();
        var minDateTimeStr = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch).toIso8601String();
        FileOper.createDirSync(['dir1', Path.join('dir2', 'dir3')], isSilent: true);

        var file = Path.fileSystem.file(Path.join('dir1', 'file1.txt'));
        file.createSync();
        file.writeAsStringSync('Test' * (1024 + 256));

        var flatMap = FlatMap();

        Functions(flatMap: flatMap, keywords: Keywords(), logger: logger)
          .exec(<String, Object?>{
            '{baseName}': [r'=baseName', file.path],
            '{baseNameNoExt}': [r'=baseNameNoExt', file.path],
            '{dirName}': [r'=dirName', file.path],
            '{dirSize}': [r'=fileSize', 'dir1'],
            '{extension}': [r'=extension', file.path],
            '{fileSize}': [r'=fileSize', file.path],
            '{fileSizeK}': [r'=fileSize', file.path, 'K'],
            '{lastModifiedDir}': [r'=lastModified', 'dir1'],
            '{lastModifiedFile}': [r'=lastModified', file.path],
          });

        expect(flatMap['{baseName}'], Path.basename(file.path));
        expect(flatMap['{baseNameNoExt}'], Path.basenameWithoutExtension(file.path));
        expect(flatMap['{dirName}'], Path.dirname(file.path));
        expect(flatMap['{extension}'], Path.extension(file.path));
        expect(flatMap['{dirSize}'], '-1');
        expect(flatMap['{fileSize}'], '5120.00');
        expect(flatMap['{fileSizeK}'], '5.00');
        expect((flatMap['{lastModifiedDir}'] ?? '').compareTo(minDateTimeStr) >= 0, true);
        expect((flatMap['{lastModifiedFile}'] ?? '').compareTo(minDateTimeStr) >= 0, true);

        FileOper.deleteSync(['dir1', 'dir2'], isSilent: true);
      });
    });
  });
}
