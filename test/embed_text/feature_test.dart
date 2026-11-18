import 'dart:io';

import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  // 子进程读取原生嵌入文本，完整比较 UTF-8 资源和末尾换行。
  test('Embedded text matches the complete resource', () async {
    await inTestProject('embed_text', (packageUri) async {
      final expected = await File.fromUri(
        packageUri.resolve('resources/message.txt'),
      ).readAsString();
      // dart format off
      final output = await runDart(
        packageUri: packageUri,
        target: 'example/main.dart',
      );                                                                  expect(output, equals(expected));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
