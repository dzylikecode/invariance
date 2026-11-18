import 'dart:ffi';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  // 未调用原生 API 时，CLI bundle 不应包含原生动态库，程序仍可正常运行。
  test('Unused native APIs omit the bundled library', () async {
    await inTestProject('project_xmake', (packageUri) async {
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/unused.dart',
      );

      // dart format off
      final filename = libraryFileName('project_xmake');
      final libraryUri = bundleUri.resolve('lib/$filename');
      final libraryExists = File.fromUri(libraryUri).existsSync();          expect(libraryExists, isFalse);

      // 同时检查整个 bundle，避免原生库只是被放到了其他目录。
      final libraries = await bundledLibraries(bundleUri, 'project_xmake'); expect(libraries, isEmpty);
      final output = (await runBundle(bundleUri)).trim();                   expect(output, equals('project_xmake'));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  // 只调用 add 时，保留其原生实现，移除 subtract 和 count_words 的导出及代码。
  test('Calling add keeps only its native implementation', () async {
    await inTestProject('project_xmake', (packageUri) async {
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/call.dart',
      );

      // dart format off
      final output = (await runBundle(bundleUri)).trim();                   expect(output, equals('8'));
      final filename = libraryFileName('project_xmake');
      final libraryUri = bundleUri.resolve('lib/$filename');
      final libraryExists = File.fromUri(libraryUri).existsSync();          expect(libraryExists, isTrue);

      final library = DynamicLibrary.open(libraryUri.toFilePath());
      try {
        final hasAdd = library.providesSymbol('add');                       expect(hasAdd, isTrue);
        final hasSubtract = library.providesSymbol('subtract');             expect(hasSubtract, isFalse);
        final hasCountWords = library.providesSymbol('count_words');        expect(hasCountWords, isFalse);
      } finally {
        // Windows 清理临时目录前需要先释放动态库句柄。
        library.close();
      }

      if (Platform.isLinux) {
        expect(
          await readDefinedSymbols(libraryUri, dynamicOnly: true),
          equals({'add'}),
        );

        // 普通符号表也不能保留未使用函数，避免把隐藏导出误判为代码裁剪。
        final definitions = await readDefinedSymbols(libraryUri);           expect(definitions, contains('add'));
        expect(
          definitions.where(
            (symbol) =>
                symbol == 'subtract' ||
                symbol.startsWith('subtract.') ||
                symbol == 'count_words' ||
                symbol.startsWith('count_words.'),
          ),
          isEmpty,
        );
      }
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
