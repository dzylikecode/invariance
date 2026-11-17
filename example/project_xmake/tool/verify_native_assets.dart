// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_util.dart' show sdkPath;
import 'package:code_assets/code_assets.dart' show Architecture;
import 'package:path/path.dart' as p;

const _assetId = 'package:project_xmake/src/project_xmake.g.dart';
const _libraryName = 'libproject_xmake.so';

Future<void> main() async {
  if (!Platform.isLinux) {
    throw UnsupportedError('This verification requires Linux and GNU nm.');
  }
  final packageRoot = p.normalize(
    p.join(p.dirname(Platform.script.toFilePath()), '..'),
  );
  final workspaceRoot = p.normalize(p.join(packageRoot, '../..'));
  final dartExecutable = p.join(
    sdkPath,
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
  final checks = Directory(
    p.join(packageRoot, '.dart_tool/native_assets_check'),
  )..createSync(recursive: true);
  final runDirectory = checks.createTempSync('run_');

  Future<ProcessResult> run(String executable, List<String> arguments) async {
    stdout.writeln('Running: $executable ${arguments.join(' ')}');
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: packageRoot,
      environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
    );
    if (result.exitCode != 0) {
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      throw ProcessException(
        executable,
        arguments,
        'Native asset verification failed',
        result.exitCode,
      );
    }
    return result;
  }

  Future<Directory> buildBundle(String entryPoint, String name) async {
    final output = p.join(runDirectory.path, name);
    final result = await run(dartExecutable, [
      'build',
      'cli',
      '--target=$entryPoint',
      '--output=$output',
    ]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return Directory(p.join(output, 'bundle'));
  }

  Future<String> runBundle(Directory bundle) async {
    final files = Directory(p.join(bundle.path, 'bin'))
        .listSync()
        .whereType<File>()
        .toList();
    _require(files.length == 1, 'Expected one executable in ${bundle.path}.');
    final result = await run(files.single.path, []);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return (result.stdout as String).trim();
  }

  Future<Set<String>> symbols(String file, {bool dynamicOnly = false}) async {
    final result = await run('nm', [
      if (dynamicOnly) '-D',
      '--defined-only',
      '--format=posix',
      file,
    ]);
    return _readSymbols(result.stdout as String);
  }

  Future<void> expectExports(String file, Set<String> expected) async {
    final actual = await symbols(file, dynamicOnly: true);
    _require(
      _sameSymbols(actual, expected),
      'Expected exports $expected in $file, found $actual.',
    );
  }

  final used = await buildBundle('example/call.dart', 'used');
  final usedLibrary = File(p.join(used.path, 'lib', _libraryName));
  _require(usedLibrary.existsSync(), 'The used bundle has no native library.');
  _require(await runBundle(used) == '8', 'The used bundle did not return 8.');
  await expectExports(usedLibrary.path, {'add'});
  final usedDefinitions = await symbols(usedLibrary.path);
  _require(
    usedDefinitions.contains('add'),
    'The used library has no inspectable regular symbol table.',
  );
  _require(
    !usedDefinitions.any(
      (symbol) =>
          symbol == 'subtract' ||
          symbol.startsWith('subtract.') ||
          symbol == 'count_words' ||
          symbol.startsWith('count_words.'),
    ),
    'Unused functions remain in the used library; hiding them is not pruning.',
  );

  final all = await buildBundle('example/all.dart', 'all');
  final allLibrary = File(p.join(all.path, 'lib', _libraryName));
  _require(
    allLibrary.existsSync(),
    'The all-symbols bundle has no native library.',
  );
  await runBundle(all);
  await expectExports(allLibrary.path, {'add', 'subtract'});

  final unused = await buildBundle('example/unused.dart', 'unused');
  final unusedLibraries = Directory(p.join(unused.path, 'lib'));
  _require(
    !unusedLibraries.existsSync() ||
        !unusedLibraries.listSync().any(
          (file) => p.basename(file.path).contains('project_xmake'),
        ),
    'The unused bundle still contains the project_xmake native library.',
  );
  await runBundle(unused);

  // Reuse an actual link input, including its archive and target configuration.
  // Removing usage records must conservatively preserve every public function.
  final hooksRoot = Directory(
    p.join(workspaceRoot, '.dart_tool/hooks_runner/project_xmake'),
  );
  final template = _findLinkInput(hooksRoot, packageRoot);
  final assets = template['assets']! as List<Object?>;
  final encoding = _archiveEncoding(assets)!;
  final archive = encoding['file']! as String;
  final archiveDefinitions = await symbols(archive);
  _require(
    archiveDefinitions.containsAll({'add', 'subtract', 'count_words'}),
    'The original archive must contain all public functions: $archive.',
  );

  final fallbackDirectory = Directory(
    p.join(runDirectory.path, 'missing_records'),
  )..createSync(recursive: true);
  final fallbackOutput = p.join(fallbackDirectory.path, 'output.json');
  final fallbackInput = Map<String, Object?>.from(template)
    ..remove('resource_identifiers')
    ..remove('out_dir')
    ..['out_dir_shared'] = p.join(fallbackDirectory.path, 'shared')
    ..['out_file'] = fallbackOutput;
  final fallbackConfig = File(p.join(fallbackDirectory.path, 'input.json'))
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(fallbackInput),
    );
  final result = await run(dartExecutable, [
    '--packages=${p.join(workspaceRoot, '.dart_tool/package_config.json')}',
    p.join(packageRoot, 'hook/link.dart'),
    '--config=${fallbackConfig.path}',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  final fallback = jsonDecode(
    File(fallbackOutput).readAsStringSync(),
  ) as Map<String, Object?>;
  _require(
    fallback['status'] == 'success',
    'The fallback link hook did not succeed.',
  );
  final fallbackAssets = fallback['assets'] as List<Object?>? ?? [];
  final fallbackLibraries = fallbackAssets
      .cast<Map<String, Object?>>()
      .where((asset) => asset['type'] == 'code_assets/code')
      .map((asset) => asset['encoding']! as Map<String, Object?>)
      .where((asset) => asset['id'] == _assetId)
      .toList();
  _require(
    fallbackLibraries.length == 1,
    'Expected one fallback native asset.',
  );
  final fallbackSymbols = await symbols(
    fallbackLibraries.single['file']! as String,
    dynamicOnly: true,
  );
  _require(
    _sameSymbols(fallbackSymbols, {'add', 'subtract', 'count_words'}),
    'Missing usage records must retain all public functions: $fallbackSymbols.',
  );

  stdout.writeln('Native asset checks passed. Artifacts: ${runDirectory.path}');
}

Map<String, Object?> _findLinkInput(Directory hooksRoot, String packageRoot) {
  _require(
    hooksRoot.existsSync(),
    'No hook inputs found at ${hooksRoot.path}.',
  );
  final candidates =
      hooksRoot
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => p.basename(file.path) == 'input.json')
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  for (final file in candidates) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    if (json['package_name'] != 'project_xmake' ||
        json['package_root'] is! String ||
        !p.equals(json['package_root']! as String, packageRoot)) {
      continue;
    }
    final config = json['config'];
    if (config is! Map<String, Object?>) continue;
    final extensions = config['extensions'];
    if (extensions is! Map<String, Object?>) continue;
    final codeAssets = extensions['code_assets'];
    if (codeAssets is! Map<String, Object?> ||
        codeAssets['target_os'] != 'linux' ||
        codeAssets['target_architecture'] != Architecture.current.name) {
      continue;
    }
    final assets = json['assets'];
    if (assets is! List<Object?>) continue;
    final encoding = _archiveEncoding(assets);
    if (encoding != null && File(encoding['file']! as String).existsSync()) {
      return json;
    }
  }
  throw StateError(
    'No actual link input with a static $_assetId asset was found.',
  );
}

Map<String, Object?>? _archiveEncoding(List<Object?> assets) {
  for (final asset in assets) {
    if (asset is! Map<String, Object?> || asset['type'] != 'code_assets/code') {
      continue;
    }
    final encoding = asset['encoding'];
    if (encoding is! Map<String, Object?> || encoding['id'] != _assetId) {
      continue;
    }
    final linkMode = encoding['link_mode'];
    if (linkMode is Map<String, Object?> &&
        linkMode['type'] == 'static' &&
        encoding['file'] is String) {
      return encoding;
    }
  }
  return null;
}

Set<String> _readSymbols(String output) => {
  for (final line in const LineSplitter().convert(output))
    if (line.trim().split(RegExp(r'\s+')) case [final name, final type, ...])
      if (type.length == 1 && RegExp(r'[A-Za-z?]').hasMatch(type))
        name.split('@').first,
};

bool _sameSymbols(Set<String> actual, Set<String> expected) =>
    actual.length == expected.length && actual.containsAll(expected);

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}
