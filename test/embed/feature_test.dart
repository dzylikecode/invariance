import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  // 子进程读取原生嵌入文本，完整比较 UTF-8 资源和末尾换行。
  test('Embedded text matches the complete resource', () async {
    await inTestProject('embed', (packageUri) async {
      final expected = await File.fromUri(
        packageUri.resolve('assets/file1.txt'),
      ).readAsString();
      final rootBytes = await File.fromUri(
        packageUri.resolve('assets/file1.txt'),
      ).readAsBytes();
      final nestedBytes = await File.fromUri(
        packageUri.resolve('assets/fold1/file1.txt'),
      ).readAsBytes();
      // dart format off
      final output = await runDart(
        packageUri: packageUri,
        target: 'example/main.dart',
      );                                                                  expect(output, equals(expected));
      final copies = await _readAssetCopies(packageUri);                    expect(copies, equals(_expectedCopies(rootBytes, nestedBytes)));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  // 仅修改临时副本，检查含零字节、非 UTF-8 内容的资源和可修改副本。
  test('Binary assets return independent byte copies', () async {
    await inTestProject('embed', (packageUri) async {
      final rootBytes = await File.fromUri(
        packageUri.resolve('assets/file1.txt'),
      ).readAsBytes();
      const nestedBytes = [0x00, 0xff, 0x41, 0x80, 0x00, 0x7f];
      await File.fromUri(packageUri.resolve('assets/fold1/file1.txt'))
          .writeAsBytes(nestedBytes);

      // dart format off
      final copies = await _readAssetCopies(packageUri);                    expect(copies, equals(_expectedCopies(rootBytes, nestedBytes)));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}

List<Map<String, String>> _expectedCopies(
  List<int> rootBytes,
  List<int> nestedBytes,
) => [
  for (final bytes in [rootBytes, nestedBytes])
    {'bytes': base64Encode(bytes), 'afterMutation': base64Encode(bytes)},
];

Future<Object?> _readAssetCopies(Uri packageUri) async {
  await File.fromUri(packageUri.resolve('example/assets_probe.dart'))
      .writeAsString('''
import 'dart:convert';
import 'dart:typed_data';

import 'package:embed/embed.dart';

void main() {
  final getters = <Uint8List Function()>[
    () => Assets.file1Txt.bytes,
    () => Assets.fold1File1Txt.bytes,
  ];
  final results = <Map<String, String>>[];
  for (final getBytes in getters) {
    final bytes = getBytes();
    final original = base64Encode(bytes);
    if (bytes.isNotEmpty) bytes[0] ^= 0xff;
    results.add({
      'bytes': original,
      'afterMutation': base64Encode(getBytes()),
    });
  }
  print(jsonEncode(results));
}
''');
  return jsonDecode(
    await runDart(packageUri: packageUri, target: 'example/assets_probe.dart'),
  );
}
