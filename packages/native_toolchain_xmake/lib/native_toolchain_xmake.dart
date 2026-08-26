import 'package:code_assets/code_assets.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'android.dart';

Future<String?> getXmakeVersion() async {
  final output = await getXmakeInfo();
  final versionMatch = RegExp(r'xmake\s+(v[\d\.]+)').firstMatch(output);
  if (versionMatch == null) return null;
  return versionMatch.group(1);
}

Future<String> getXmakeInfo() async {
  final result = await Process.run('xmake', ['--version']);
  if (result.exitCode != 0) {
    throw Exception(
      'Failed to get xmake info (exit ${result.exitCode}):\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
  return result.stdout.toString().trim();
}

Future<bool> hasXmake() =>
    getXmakeInfo().then((_) => true).catchError((_) => false);

Future<void> _ensureXmakeInstalled(Logger logger) async {
  if (!await hasXmake()) {
    throw Exception(
      'Failed to install xmake. Please install it manually and try again. '
      'See https://xmake.io/guide/quick-start.html for installation instructions.',
    );
  }
  final xmakeVersion = await getXmakeVersion();
  if (xmakeVersion == null) {
    throw StateError(
      'xmake is installed but not found in the current environment. '
      'Restart the terminal or the system for PATH changes to take effect.',
    );
  }
  logger.info('Using xmake version: $xmakeVersion');
}

class XmakeBuilder {
  final Logger _logger;
  final String project;
  final CodeConfig codeConfig;
  final String packageName;
  final AndroidTool _androidTool;

  XmakeBuilder._({
    Logger? logger,
    required this.project,
    required this.codeConfig,
    required this.packageName,
  }) : _logger = logger ?? Logger('XmakeBuilder')
         ..onRecord.listen((record) {
           print('[${record.level.name}] ${record.message}');
         }),
       _androidTool = AndroidTool(codeConfig);

  static Future<XmakeBuilder> create({
    Logger? logger,
    required String project,
    required CodeConfig codeConfig,
    required String packageName,
    String androidNdk = '',
    String iosSdk = '',
  }) async {
    final builder = XmakeBuilder._(
      logger: logger,
      project: project,
      codeConfig: codeConfig,
      packageName: packageName,
    );
    await _ensureXmakeInstalled(builder._logger);
    builder._logger.info('XmakeBuilder created for project: $project');
    return builder;
  }

  Future<void> _xmake(List<String> args) async {
    final result = await Process.run('xmake', args, workingDirectory: project);
    if (result.exitCode != 0) {
      throw Exception(
        'xmake ${args.join(' ')} failed (exit ${result.exitCode}):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
  }

  // see https://xmake.io/guide/basic-commands/build-configuration.html
  Future<void> config() async {
    final (os, arch) = _target(
      codeConfig.targetOS,
      codeConfig.targetArchitecture,
    );

    return _xmake([
      'f',
      '-P',
      '.',
      '-v',
      '--plat=$os',
      '--arch=$arch',
      // dart format off
      ...switch (codeConfig.targetOS) {
        .android => () {
                      final ndk = _androidTool.ndk;
                      final bin = _androidTool.bin;
                      return [
                        '--toolchain=ndk',
                        if (ndk != null) '--ndk=$ndk',
                        if (bin != null) '--bin=$bin',
                      ];
                    }(),
        .iOS     => [
                      if (codeConfig.iOS.targetSdk == .iPhoneSimulator)
                        '--appledev=simulator',
                    ],
        // desktop
        _        => [
                      // cross compile
                      if (codeConfig.targetOS.name != Platform.operatingSystem)
                        '--toolchain=zigcc', // it's zigcc instead of zig !!!
                    ],
      },
      // dart format on
      '--mode=release',
      '--kind=shared',
      '-y',
    ]);
  }

  Future<void> build({String? target}) {
    return _xmake(['-P', '.', ?target]); // 有可能嵌套了一个 xmake
  }

  /// export the library to the specified directory, and return the path of the installed library file.
  ///
  /// [installDir] relative to the project root, default is 'dist'
  Future<String> install({
    String? target,
    String installDir = 'dist',
    String? libName,
  }) async {
    final (os, arch) = _target(
      codeConfig.targetOS,
      codeConfig.targetArchitecture,
    );
    installDir = p.join(project, installDir, os, arch);
    await _xmake(['install', '-P', '.', '--installdir=$installDir', ?target]);

    final libDir = p.join(installDir, switch (codeConfig.targetOS) {
      .windows => 'bin',
      _ => 'lib',
    });

    final dllName = codeConfig.targetOS.libraryFileName(
      libName ?? packageName,
      DynamicLoadingBundled(),
    );

    final libPath = p.join(libDir, dllName);
    // 优先找这个文件
    if (await File(libPath).exists()) {
      return libPath;
    }

    // 特例：
    // - linux: libName.so.1.2.3
    // - mac  : libName.1.2.3.dylib
    // 用 libName 来搜索
    final dllBaseName = p.basenameWithoutExtension(dllName);
    final files = await Directory(libDir).list().where((file) {
      return file is File && p.basename(file.path).startsWith(dllBaseName);
    }).toList();

    if (files.isEmpty) {
      throw Exception('No library files found in $libDir for $dllName');
    }
    files.sort(
      (a, b) => p.basename(a.path).length.compareTo(p.basename(b.path).length),
    );
    return files.first.path;
  }
}

(String, String) _target(OS os, Architecture arch) {
  // dart format off
  return switch ((os, arch)) {
    // Windows
    (.windows, .x64)     => ('windows', 'x64'),
    (.windows, .ia32)    => ('windows', 'x86'),
    (.windows, .arm)     => ('windows', 'arm'),
    (.windows, .arm64)   => ('windows', 'arm64'),

    // Linux
    (.linux, .x64)       => ('linux', 'x86_64'),
    (.linux, .ia32)      => ('linux', 'i386'),
    (.linux, .arm)       => ('linux', 'armv7'),
    (.linux, .arm64)     => ('linux', 'arm64'),
    (.linux, .riscv64)   => ('linux', 'riscv64'),

    // macOS
    (.macOS, .x64)       => ('macosx', 'x86_64'),
    (.macOS, .arm64)     => ('macosx', 'arm64'),

    // Android
    (.android, .arm)     => ('android', 'armeabi-v7a'),
    (.android, .arm64)   => ('android', 'arm64-v8a'),
    (.android, .ia32)    => ('android', 'x86'),
    (.android, .x64)     => ('android', 'x86_64'),
    (.android, .riscv64) => ('android', 'riscv64'),

    // iOS
    (.iOS, .arm64)       => ('iphoneos', 'arm64'),
    (.iOS, .x64)         => ('iphoneos', 'x86_64'),

    // Unsupported
    (.fuchsia, _)        => throw UnsupportedError('Unsupported OS for xmake: $os'),
    _                    => throw UnsupportedError(
                              'Unsupported OS/arch combination for xmake: $os/$arch',
                            ),
  // dart format on
  };
}
