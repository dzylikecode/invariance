import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';

import 'android.dart';

Future<String> getXmakeVersion() async {
  final output = await getXmakeInfo();
  final versionMatch = RegExp(r'xmake\s+v([\d\.]+)').firstMatch(output);
  return versionMatch!.group(1)!;
}

Future<String> getXmakeInfo() async {
  final result = await Process.run('xmake', ['--version']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'xmake',
      ['--version'],
      'Failed to get xmake version: ${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout.toString().trim();
}

// dart format off
Future<bool> hasXmake() =>  Process.run('xmake', ['--version'])
                              .then((result) => result.exitCode == 0)
                              .catchError((_) => false);
// dart format on

enum Kind {
  static,
  shared;

  @override
  String toString() => name;
}

class Xmake({
  required final String projectRoot,
  required final CodeConfig codeConfig,
  final Kind kind = .shared,
  required final Logger logger,
}) {
  final AndroidTool _androidTool = AndroidTool(codeConfig);

  Future<void> call(List<String> args) async {
    final result = await Process.run(
      'xmake',
      args,
      workingDirectory: projectRoot,
      // 1. 文本模式显示不了颜色
      // 2. 报错的时候，显示的颜色只是红色
      // 所以禁止颜色输出
      environment: {...Platform.environment, 'XMAKE_COLORTERM': 'nocolor'},
    );
    logger.info("""
$projectRoot>xmake ${args.join(' ')}
${result.stdout}
""");
    if (result.exitCode != 0) {
      logger.severe(result.stderr);
      throw ProcessException(
        'xmake',
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  // see https://xmake.io/guide/basic-commands/build-configuration.html
  Future<void> config() async {
    final (os, arch) = _target(
      codeConfig.targetOS,
      codeConfig.targetArchitecture,
    );

    return call([
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
      '--kind=$kind',
      '-y',
    ]);
  }

  Future<void> build({String? target}) =>
      call(['-P', '.', ?target]); // 有可能嵌套了一个 xmake

  /// export the library to the specified directory, and return the path of the installed library file.
  ///
  /// [installDir] relative to the project root, default is 'dist'
  Future<void> install({String? target, required String installDir}) =>
      call(['install', '-P', '.', '--installdir=$installDir', ?target]);
}

(String, String) _target(OS os, Architecture arch) => switch ((os, arch)) {
  // dart format off
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

Future<String> findLibraryFile(String libName, String searchDir) async {
  final libPath = p.join(searchDir, libName);
  // 优先找这个文件
  if (await File(libPath).exists()) return libPath;

  // 特例：
  // - linux: name.so.1.2.3
  // - mac  : name.1.2.3.dylib
  // 用 name 来搜索
  final name = p.basenameWithoutExtension(libName);
  final files = await Directory(searchDir).list().where((file) {
    return file is File && p.basename(file.path).startsWith(name);
  }).toList();

  if (files.isEmpty) {
    throw Exception('No library files found in $searchDir for $name');
  }
  files.sort(
    (a, b) => p.basename(a.path).length.compareTo(p.basename(b.path).length),
  );
  return files.first.path;
}
