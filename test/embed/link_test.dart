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
        final hasSize = library.providesSymbol('asset_file1_txt_size');     expect(hasSize, isTrue);
        final hasData = library.providesSymbol('asset_file1_txt_data');     expect(hasData, isFalse);
      } finally {
        // Windows 清理临时目录前先释放句柄。
        library.close();
      }

      if (Platform.isLinux) {
        final exports = await readDefinedSymbols(libraryUri, dynamicOnly: true);
        expect(exports, equals({'asset_file1_txt_size'}));

        // 普通表和原始资源字节都检查，区分隐藏导出与实际删除代码、数据。
        final definitions = await readDefinedSymbols(libraryUri);           expect(definitions, contains('asset_file1_txt_size'));
        expect(
          definitions.where((symbol) =>
              symbol == 'asset_file1_txt_data' ||
              symbol.startsWith('asset_file1_txt_data.') ||
              symbol == 'asset_file1_txt' || symbol.startsWith('asset_file1_txt.')),
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

  // 仅通过公共资源 API 读取根资源，嵌套资源的函数和二进制数据都应被 GC。
  test('Reading one asset drops the unused nested asset', () async {
    await inTestProject('embed', (packageUri) async {
      final expected = await File.fromUri(
        packageUri.resolve('assets/file1.txt'),
      ).readAsString();
      final unusedResource = [
        0x00,
        0xff,
        ...utf8.encode('unused_nested_asset_87bd1e02_5c49_43be'),
        0x80,
        0x00,
      ];
      await File.fromUri(packageUri.resolve('assets/fold1/file1.txt'))
          .writeAsBytes(unusedResource);
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/main.dart',
      );

      // dart format off
      final output = await runBundle(bundleUri);                           expect(output, equals(expected));
      final filename = libraryFileName('embed');
      final libraryUri = bundleUri.resolve('lib/$filename');
      final libraryExists = File.fromUri(libraryUri).existsSync();          expect(libraryExists, isTrue);

      final library = DynamicLibrary.open(libraryUri.toFilePath());
      try {
        final hasData = library.providesSymbol('asset_file1_txt_data');     expect(hasData, isTrue);
        final hasSize = library.providesSymbol('asset_file1_txt_size');     expect(hasSize, isTrue);
        final hasNestedData = library.providesSymbol('asset_fold1_file1_txt_data'); expect(hasNestedData, isFalse);
        final hasNestedSize = library.providesSymbol('asset_fold1_file1_txt_size'); expect(hasNestedSize, isFalse);
      } finally {
        library.close();
      }

      if (Platform.isLinux) {
        final exports = await readDefinedSymbols(libraryUri, dynamicOnly: true);
        expect(exports, equals({'asset_file1_txt_data', 'asset_file1_txt_size'}));

        final definitions = await readDefinedSymbols(libraryUri);
        expect(
          definitions.where((symbol) =>
              symbol == 'asset_fold1_file1_txt_data' ||
              symbol.startsWith('asset_fold1_file1_txt_data.') ||
              symbol == 'asset_fold1_file1_txt_size' ||
              symbol.startsWith('asset_fold1_file1_txt_size.') ||
              symbol == 'asset_fold1_file1_txt' ||
              symbol.startsWith('asset_fold1_file1_txt.')),
          isEmpty,
        );
        final bytes = await File.fromUri(libraryUri).readAsBytes();
        final retainsUnusedResource = latin1.decode(bytes).contains(
          latin1.decode(unusedResource),
        );                                                                expect(retainsUnusedResource, isFalse);
      }
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
