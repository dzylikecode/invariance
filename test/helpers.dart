import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cli_util/cli_util.dart' show sdkPath;
import 'package:code_assets/code_assets.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _dart = p.join(sdkPath, 'bin', Platform.isWindows ? 'dart.exe' : 'dart');

String libraryFileName(String name) =>
    OS.current.libraryFileName(name, DynamicLoadingBundled());

Future<void> inTestProject(
  String name,
  Future<void> Function(Uri packageUri) action,
) async {
  final libraryRoot = (await Isolate.resolvePackageUri(
    Uri.parse('package:invariance/'),
  ))!;
  final repository = libraryRoot.resolve('../');
  final directory = await Directory.systemTemp.createTemp('${name}_test_');
  final root = Directory(await directory.resolveSymbolicLinks()).uri;
  printOnFailure('Test workspace: $root');
  try {
    // 保留仓库相对布局，复制源码和资源，排除旧产物及本地路径锁。
    final packageUri = root.resolve('example/$name/');
    await _copy(repository.resolve('example/$name/'), packageUri);
    final toolchain = root.resolve('packages/native_toolchain_xmake/');
    for (final entry in ['pubspec.yaml', 'lib', 'xmake']) {
      await _copy(
        repository.resolve('packages/native_toolchain_xmake/$entry'),
        toolchain.resolve(entry),
      );
    }
    await _copy(
      repository.resolve('packages/d/dart_native/'),
      root.resolve('packages/d/dart_native/'),
    );
    final lockfile = File.fromUri(repository.resolve('pubspec.lock'));
    if (await lockfile.exists()) {
      await lockfile.copy(root.resolve('pubspec.lock').toFilePath());
    }
    await File.fromUri(root.resolve('pubspec.yaml')).writeAsString('''
name: native_example_tests
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - example/$name
  - packages/native_toolchain_xmake
''');
    await _run(_dart, ['pub', 'get'], workingDirectory: root);
    await action(packageUri);
  } finally {
    if (Platform.environment['KEEP_TEMPORARY_DIRECTORIES']?.isNotEmpty ??
        false) {
      print('KEEP_TEMPORARY_DIRECTORIES: $root');
    } else {
      await directory.delete(recursive: true);
    }
  }
}

Future<void> _copy(Uri source, Uri destination) async {
  const ignored = {
    '.dart_tool',
    '.xmake',
    '.cache',
    '.git',
    'build',
    'dist',
    'xmake-requires.lock',
    'pubspec.lock',
  };
  if (ignored.contains(p.basename(source.toFilePath()))) return;
  if (await File.fromUri(source).exists()) {
    final file = File.fromUri(destination);
    await file.parent.create(recursive: true);
    await File.fromUri(source).copy(file.path);
  } else {
    final directory = Directory.fromUri(destination);
    await directory.create(recursive: true);
    await for (final entity in Directory.fromUri(
      source,
    ).list(followLinks: false)) {
      await _copy(entity.uri, directory.uri.resolve(p.basename(entity.path)));
    }
  }
}

Future<String> runDart({required Uri packageUri, required String target}) =>
    _run(_dart, ['run', target], workingDirectory: packageUri);

Future<Uri> buildCli({required Uri packageUri, required String target}) async {
  final output = packageUri.resolve(
    'build/cli/${p.basenameWithoutExtension(target)}/',
  );
  await _run(_dart, [
    'build',
    'cli',
    '--target=$target',
    '--output=${output.toFilePath()}',
  ], workingDirectory: packageUri);
  return output.resolve('bundle/');
}

Future<String> runBundle(Uri bundleUri) async {
  final executables =
      (await Directory.fromUri(bundleUri.resolve('bin/')).list().toList())
          .whereType<File>()
          .where(
            (file) => !Platform.isWindows || p.extension(file.path) == '.exe',
          )
          .toList();
  expect(executables, hasLength(1));
  return _run(executables.single.path, []);
}

Future<List<String>> bundledLibraries(Uri bundleUri, String name) async {
  final suffix = RegExp(r'\.(?:so(?:\.\d+)*|dylib|dll)$');
  return Directory.fromUri(bundleUri)
      .list(recursive: true, followLinks: false)
      .where((entity) {
        final file = p.basename(entity.path).toLowerCase();
        return (file.startsWith(name) || file.startsWith('lib$name')) &&
            suffix.hasMatch(file);
      })
      .map((entity) => entity.path)
      .toList();
}

Future<Set<String>> readDefinedSymbols(
  Uri library, {
  bool dynamicOnly = false,
}) async {
  final output = await _run('nm', [
    if (dynamicOnly) '-D',
    '--defined-only',
    '--format=posix',
    library.toFilePath(),
  ]);
  return {
    for (final line in const LineSplitter().convert(output))
      if (line.trim().split(RegExp(r'\s+')) case [final name, final type, ...])
        if (type.length == 1 && RegExp(r'[A-Za-z?]').hasMatch(type))
          name.split('@').first,
  };
}

Future<String> _run(
  String executable,
  List<String> args, {
  Uri? workingDirectory,
}) async {
  printOnFailure('Running in $workingDirectory: $executable $args');
  final result = await Process.run(
    executable,
    args,
    workingDirectory: workingDirectory?.toFilePath(),
    environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
  );
  printOnFailure('${result.stdout}\n${result.stderr}');
  expect(result.exitCode, 0, reason: '$executable failed: $args');
  return result.stdout as String;
}
