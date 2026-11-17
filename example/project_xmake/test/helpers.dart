// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cli_util/cli_util.dart' show sdkPath;
import 'package:code_assets/code_assets.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _dartExecutable = p.join(
  sdkPath,
  'bin',
  Platform.isWindows ? 'dart.exe' : 'dart',
);

String get libraryFileName =>
    OS.current.libraryFileName('project_xmake', DynamicLoadingBundled());

Future<T> inTempDir<T>(Future<T> Function(Uri tempUri) action) async {
  final directory = await Directory.systemTemp.createTemp(
    'project_xmake_test_',
  );
  final uri = Directory(await directory.resolveSymbolicLinks()).uri;
  printOnFailure('Test workspace: $uri');
  try {
    return await action(uri);
  } finally {
    if (Platform.environment['KEEP_TEMPORARY_DIRECTORIES']?.isNotEmpty ??
        false) {
      print('KEEP_TEMPORARY_DIRECTORIES: $uri');
    } else {
      await directory.delete(recursive: true);
    }
  }
}

Future<Uri> copyTestProject({required Uri targetUri}) async {
  final packageRoot = (await Isolate.resolvePackageUri(
    Uri.parse('package:project_xmake/project_xmake.dart'),
  ))!.resolve('../');
  final toolchainRoot = (await Isolate.resolvePackageUri(
    Uri.parse('package:native_toolchain_xmake/native_toolchain_xmake.dart'),
  ))!.resolve('../');
  final packageUri = targetUri.resolve('example/project_xmake/');
  final toolchainUri = targetUri.resolve('packages/native_toolchain_xmake/');

  // 只复制源码；local 包的 port 目录内也可能存在旧的构建配置。
  for (final name in ['pubspec.yaml', 'xmake.lua', 'xmake-requires.lock']) {
    await _copyFile(packageRoot.resolve(name), packageUri.resolve(name));
  }
  for (final name in ['example', 'hook', 'include', 'lib', 'local', 'src']) {
    await _copyDirectory(
      Directory.fromUri(packageRoot.resolve('$name/')),
      Directory.fromUri(packageUri.resolve('$name/')),
    );
  }
  await _copyFile(
    toolchainRoot.resolve('pubspec.yaml'),
    toolchainUri.resolve('pubspec.yaml'),
  );
  await _copyDirectory(
    Directory.fromUri(toolchainRoot.resolve('lib/')),
    Directory.fromUri(toolchainUri.resolve('lib/')),
  );

  // 小 workspace 让示例使用当前工具链源码，同时保留原来的相对目录。
  await File.fromUri(targetUri.resolve('pubspec.yaml')).writeAsString('''
name: project_xmake_link_tests
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - example/project_xmake
  - packages/native_toolchain_xmake
''');
  final lockfile = packageRoot.resolve('../../pubspec.lock');
  if (await File.fromUri(lockfile).exists()) {
    await _copyFile(lockfile, targetUri.resolve('pubspec.lock'));
  }
  return packageUri;
}

Future<void> _copyFile(Uri source, Uri target) async {
  final file = File.fromUri(target);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await File.fromUri(source).readAsBytes());
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  const generatedDirectories = {
    '.dart_tool',
    '.xmake',
    'build',
    'dist',
    '.cache',
  };
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = p.basename(entity.path);
    if (entity is Directory) {
      if (!generatedDirectories.contains(name)) {
        await _copyDirectory(entity, Directory(p.join(target.path, name)));
      }
    } else if (entity is File) {
      await _copyFile(entity.uri, File(p.join(target.path, name)).uri);
    }
  }
}

Future<void> runPubGet({required Uri workingDirectory}) async {
  await _runProcess(_dartExecutable, [
    'pub',
    'get',
  ], workingDirectory: workingDirectory);
}

Future<Uri> buildCli({required Uri packageUri, required String target}) async {
  final output = packageUri.resolve('build/cli/');
  await _runProcess(_dartExecutable, [
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
  final result = await _runProcess(executables.single.path, []);
  return (result.stdout as String).trim();
}

Future<Set<String>> readDefinedSymbols(
  Uri libraryUri, {
  bool dynamicOnly = false,
}) async {
  final result = await _runProcess('nm', [
    if (dynamicOnly) '-D',
    '--defined-only',
    '--format=posix',
    libraryUri.toFilePath(),
  ]);
  return {
    for (final line in const LineSplitter().convert(result.stdout as String))
      if (line.trim().split(RegExp(r'\s+')) case [final name, final type, ...])
        if (type.length == 1 && RegExp(r'[A-Za-z?]').hasMatch(type))
          name.split('@').first,
  };
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments, {
  Uri? workingDirectory,
}) async {
  printOnFailure('Running in $workingDirectory: $executable $arguments');
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory?.toFilePath(),
    environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
  );
  printOnFailure('${result.stdout}\n${result.stderr}');
  expect(result.exitCode, 0, reason: '$executable failed: $arguments');
  return result;
}
