import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  // 在临时工程中运行 Dart 示例，验证直接打包动态库时仍可调用原生接口。
  test('3 + 5 = 8', () async {
    await inTestProject('project_xmake', (packageUri) async {
      final output = await runDart(
        packageUri: packageUri,
        target: 'example/call.dart',
      );

      // dart format off
      final result = output.trim();                                      expect(result, equals('8'));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
