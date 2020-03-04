import 'package:doul/config.dart';
import 'package:test/test.dart';

void main() {
  test('calculate', () async {
    var args = { '-c', 'data/doul.json', };

    expect(await Config.exec(args.toList()), true);
  });
}
