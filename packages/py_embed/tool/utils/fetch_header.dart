import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:console_bars/console_bars.dart';

Future<void> fetchHeaders(List<String> versions, Uri packageRoot) async {
  final rootDir = Directory.fromUri(packageRoot);
  final cacheDir = Directory(p.join(rootDir.path, '.cache', 'cpython'));
  final distDir = Directory(p.join(rootDir.path, 'dist'));

  await cacheDir.create(recursive: true);
  await distDir.create(recursive: true);

  for (final version in versions) {
    await _fetchHeaders(
      version: version,
      rootDir: rootDir,
      cacheDir: cacheDir,
      distDir: distDir,
    );
  }
}

Future<void> _fetchHeaders({
  required String version,
  required Directory rootDir,
  required Directory cacheDir,
  required Directory distDir,
}) async {
  final repoDir = await fetchRepo(version, cacheDir);
  final sourceInclude = Directory(p.join(repoDir.path, 'Include'));
  if (!await sourceInclude.exists()) {
    throw StateError('Missing Include directory in ${repoDir.path}');
  }

  final targetInclude = Directory(p.join(distDir.path, version, 'include'));
  if (!await targetInclude.exists()) {
    await targetInclude.create(recursive: true);
    await _copyDirectory(sourceInclude, targetInclude);
  }

  final pyConfig = await getPyConfig(repoDir, version);
  final pyConfigTagetPath = p.join(targetInclude.path, 'pyconfig.h');
  await pyConfig.copy(pyConfigTagetPath);
}

Future<Directory> fetchRepo(String version, Directory cacheDir) async {
  final repoDir = Directory(p.join(cacheDir.path, 'Python-$version'));
  if (await repoDir.exists()) {
    print('use the cached repo: $repoDir');
    return repoDir;
  }

  final archiveName = 'Python-$version.tar.xz';
  final archiveFile = File(p.join(cacheDir.path, archiveName));
  final url = Uri.parse(
    'https://www.python.org/ftp/python/$version/$archiveName',
  );

  if (!await archiveFile.exists()) {
    print('fetch $url to $archiveFile');
    late FillingBar bar;
    await _download(
      url,
      archiveFile,
      onTotal: (total) {
        bar = FillingBar(
          desc: 'Downloading',
          total: total,
          percentage: true,
          time: true,
          width: stdout.hasTerminal ? null : 60,
        );
      },
      onProgress: (downloaded) => bar.update(downloaded),
    );
    print(''); // 为了换行
  } else {
    print('Using cached $archiveFile');
  }

  print('Extracting $archiveFile');
  await tar(archiveFile, cacheDir);
  return repoDir;
}

Future<File> getPyConfig(Directory sourceRoot, String version) async {
  if (Platform.isWindows) {
    return getPyConfigWin(sourceRoot, version);
  }

  return getPyConfigPosix(sourceRoot);
}

Future<File> getPyConfigWin(Directory sourceRoot, String version) async {
  final pyConfig = File(p.join(sourceRoot.path, 'PC', 'pyconfig.h'));
  // CPython <= 3.12 会自带 pyconfig.h
  if (await pyConfig.exists()) return pyConfig;
  // CPython 3.13+ 会在 PCbuild 目录下生成 pyconfig.h
  final pcbuild = Directory(p.join(sourceRoot.path, 'PCbuild'));
  final project = File(p.join(pcbuild.path, 'pythoncore.vcxproj'));
  if (!await project.exists()) {
    throw StateError('Missing CPython PCbuild project in ${pcbuild.path}');
  }

  final versionParts = version.split('.');
  final versionTag = '${versionParts[0]}${versionParts[1]}';
  final generated = File(
    p.join(
      pcbuild.path,
      'obj',
      '${versionTag}amd64_Release',
      'pythoncore',
      'pyconfig.h',
    ),
  );
  if (!await generated.exists()) {
    // CPython 3.13+ generates pyconfig.h from PC/pyconfig.h.in. Invoke only
    // its MSBuild target: build.bat would also locate or download Python.
    stdout.writeln('Generating ${generated.path} with PCbuild');
    final msBuild = await _findMsBuild();
    final result = await Process.run(
      msBuild,
      [
        project.path,
        '/t:_UpdatePyconfig',
        '/nologo',
        '/v:m',
        '/p:Configuration=Release',
        '/p:Platform=x64',
      ],
      workingDirectory: pcbuild.path,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        project.path,
        ['/t:_UpdatePyconfig', '/p:Configuration=Release', '/p:Platform=x64'],
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
  }

  if (!await generated.exists()) {
    throw StateError('PCbuild did not generate ${generated.path}');
  }
  return generated;
}

Future<File> getPyConfigPosix(Directory sourceRoot) async {
  final pyConfig = File(p.join(sourceRoot.path, 'pyconfig.h'));
  if (await pyConfig.exists()) {
    stdout.writeln('Using generated ${pyConfig.path}');
    return pyConfig;
  }

  final configure = File(p.join(sourceRoot.path, 'configure'));
  if (!await configure.exists()) {
    throw StateError('Missing configure script at ${configure.path}');
  }

  print('Generating ${pyConfig.path}');
  final result = await Process.run(configure.path, [
    '--enable-shared',
  ], workingDirectory: sourceRoot.path);

  if (result.exitCode != 0) {
    throw ProcessException(
      configure.path,
      ['--enable-shared'],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }

  if (!await pyConfig.exists()) {
    throw StateError('configure did not generate ${pyConfig.path}');
  }

  return pyConfig;
}

Future<String> _findMsBuild() async {
  final onPath = await Process.run('where.exe', ['msbuild.exe']);
  if (onPath.exitCode == 0) {
    final path = (onPath.stdout as String).split(RegExp(r'\r?\n')).first.trim();
    if (path.isNotEmpty) return path;
  }

  final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
  if (programFilesX86 != null) {
    final vswhere = File(
      p.join(
        programFilesX86,
        'Microsoft Visual Studio',
        'Installer',
        'vswhere.exe',
      ),
    );
    if (await vswhere.exists()) {
      final result = await Process.run(vswhere.path, [
        '-latest',
        '-prerelease',
        '-products',
        '*',
        '-requires',
        'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '-property',
        'installationPath',
      ]);
      if (result.exitCode == 0) {
        final installPath = (result.stdout as String).trim();
        for (final version in ['Current', '15.0']) {
          final msBuild = File(
            p.join(installPath, 'MSBuild', version, 'Bin', 'MSBuild.exe'),
          );
          if (await msBuild.exists()) return msBuild.path;
        }
      }
    }
  }

  throw StateError('Unable to locate MSBuild.exe');
}

Future<void> _download(
  Uri url,
  File output, {
  void Function(int total)? onTotal,
  void Function(int downloaded)? onProgress,
}) async {
  final client = HttpClient();

  try {
    final request = await client.getUrl(url);
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $url: HTTP ${response.statusCode}',
        uri: url,
      );
    }

    final total = response.contentLength;
    onTotal?.call(total);

    var downloaded = 0;

    final tempFile = File('${output.path}.download');
    final sink = tempFile.openWrite();

    try {
      await response
          .map((chunk) {
            downloaded += chunk.length;
            onProgress?.call(downloaded);
            return chunk;
          })
          .pipe(sink);
    } finally {
      await sink.close();
    }

    if (await output.exists()) {
      await output.delete();
    }

    await tempFile.rename(output.path);
  } finally {
    client.close(force: true);
  }
}

Future<void> tar(File archiveFile, Directory extractDir) async {
  // windows 有 tar
  final result = await Process.run('tar', [
    '-xf',
    archiveFile.path,
    '-C',
    extractDir.path,
  ]);

  if (result.exitCode != 0) {
    throw ProcessException(
      'tar',
      ['-xf', archiveFile.path, '-C', extractDir.path],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await for (final entity in source.list(recursive: true)) {
    final relativePath = _relative(source, entity);
    final targetPath = p.join(target.path, relativePath);

    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(File(targetPath).parent.path).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

String _relative(Directory from, FileSystemEntity entity) {
  return p.relative(entity.path, from: from.path);
}
