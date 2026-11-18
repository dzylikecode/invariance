import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  // 不使用原生 API 时，bundle 不携带本例动态库，程序仍可正常运行。
  test('Unused native APIs omit the bundled library', () async {
    await inTestProject('embed', (packageUri) async {
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/unused.dart',
      );

      // dart format off
      final output = (await runBundle(bundleUri)).trim();                   expect(output, equals('embed'));
      final filename = libraryFileName('embed');
      final libraryUri = bundleUri.resolve('lib/$filename');
      final libraryExists = File.fromUri(libraryUri).existsSync();          expect(libraryExists, isFalse);

      // 检查整个 bundle，避免库只是被安装到了其他目录。
      final libraries = await bundledLibraries(bundleUri, 'embed');         expect(libraries, isEmpty);
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  // size 返回编译时常量；保留它不应连带保留 data 函数和静态文本资源。
  test('Calling size drops the unused data API and resource', () async {
    await inTestProject('embed', (packageUri) async {
      final resource = await File.fromUri(
        packageUri.resolve('assets/file1.txt'),
      ).readAsBytes();
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/size.dart',
      );

      // dart format off
      final output = (await runBundle(bundleUri)).trim();                   expect(output, equals('${resource.length}'));
      final filename = libraryFileName('embed');
      final libraryUri = bundleUri.resolve('lib/$filename');
      final libraryExists = File.fromUri(libraryUri).existsSync();          expect(libraryExists, isTrue);

      final library = DynamicLibrary.open(libraryUri.toFilePath());
      try {
        final hasSize = library.providesSymbol('file1_size');               expect(hasSize, isTrue);
        final hasData = library.providesSymbol('file1_data');               expect(hasData, isFalse);
      } finally {
        // Windows 清理临时目录前先释放句柄。
        library.close();
      }

      if (Platform.isLinux) {
        final exports = await readDefinedSymbols(libraryUri, dynamicOnly: true);
        expect(exports, equals({'file1_size'}));

        // 普通表和原始资源字节都检查，区分隐藏导出与实际删除代码、数据。
        final definitions = await readDefinedSymbols(libraryUri);           expect(definitions, contains('file1_size'));
        expect(
          definitions.where((symbol) =>
              symbol == 'file1_data' ||
              symbol.startsWith('file1_data.') ||
              symbol == 'file1_txt' || symbol.startsWith('file1_txt.')),
          isEmpty,
        );
        if (resource.isNotEmpty) {
          final bytes = await File.fromUri(libraryUri).readAsBytes();
          final retainsResource = latin1.decode(bytes).contains(
            latin1.decode(resource),
          );                                                                expect(retainsResource, isFalse);
        }
      }
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
