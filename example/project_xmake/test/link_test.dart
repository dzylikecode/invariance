// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  // 未调用原生 API 时，CLI bundle 不应包含原生动态库，程序仍可正常运行。
  test('Unused native APIs omit the bundled library', () async {
    await inTempDir((tempUri) async {
      final packageUri = await copyTestProject(targetUri: tempUri);
      await runPubGet(workingDirectory: tempUri);
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/unused.dart',
      );

      // dart format off
      final libraryUri = bundleUri.resolve('lib/$libraryFileName');
      final libraryExists = File.fromUri(libraryUri).existsSync();          expect(libraryExists, isFalse);

      // 同时检查整个 bundle，避免原生库只是被放到了其他目录。
      final dynamicLibrarySuffix = RegExp(r'\.(?:so(?:\.\d+)*|dylib|dll)$');
      final bundledLibraries = await Directory.fromUri(bundleUri)
          .list(recursive: true, followLinks: false)
          .where((entity) {
            final name = p.basename(entity.path).toLowerCase();
            return (name.startsWith('project_xmake') ||
                    name.startsWith('libproject_xmake')) &&
                dynamicLibrarySuffix.hasMatch(name);
          })
          .map((entity) => entity.path)
          .toList();                                                        expect(bundledLibraries, isEmpty);
      final output = (await runBundle(bundleUri)).trim();                   expect(output, equals('project_xmake'));
      // dart format on
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  // 只调用 add 时，保留其原生实现，移除 subtract 和 count_words 的导出及代码。
  test('Calling add keeps only its native implementation', () async {
    await inTempDir((tempUri) async {
      final packageUri = await copyTestProject(targetUri: tempUri);
      await runPubGet(workingDirectory: tempUri);
      final bundleUri = await buildCli(
        packageUri: packageUri,
        target: 'example/call.dart',
      );

      // dart format off
      final output = (await runBundle(bundleUri)).trim();                   expect(output, equals('8'));
      final libraryUri = bundleUri.resolve('lib/$libraryFileName');
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
