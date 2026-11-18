import 'dart:convert';

import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  // 默认从固定远程 commit 安装规则，运行 C++ 模板的整数和浮点实例。
  test('C++ template instances support int and double', () async {
    await inTestProject('template_adapter', (packageUri) async {
      final output = await runDart(
        packageUri: packageUri,
        target: 'example/main.dart',
      );

      // dart format off
      final lines = const LineSplitter().convert(output);                  expect(lines, equals(['int: 8', 'double: 3.75']));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
