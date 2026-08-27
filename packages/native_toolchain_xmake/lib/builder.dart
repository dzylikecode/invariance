import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'xmake.dart';

class XmakeBuilder({
  /// name of xmake target
  required final String target,

  /// name of the library to be linked, if null, use [target] as the library name
  ///
  /// This is useful when the target name does not equal to the library name, for example:
  ///
  /// ```lua
  /// target("minimal")
  ///   set_kind("binary")
  ///   add_files("example/main.cpp")
  ///   add_packages("raylib")
  /// ```
  ///
  /// In this case, the target name is "minimal",
  /// but the library to be used is "raylib".
  String? libHintName,
  required final String assetName,
  required final Uri projectRoot,

  /// The directory where the library will be installed, if null, use `$projectRoot/dist`
  required Uri? installDir,
}) {
  final libHintName = libHintName ?? target;
  final installDir = installDir ?? projectRoot.resolve('dist');

  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
  }) async {
    if (!await hasXmake()) {
      // TODO: 修改一下提示
      throw Exception(
        'Failed to install xmake. Please install it manually and try again. '
        'See https://xmake.io/guide/quick-start.html for installation instructions.',
      );
    }

    final xmake = Xmake(
      projectRoot: projectRoot.toFilePath(),
      codeConfig: input.config.code,
    );

    await xmake.config();
    await xmake.build(target: target);
    final platformInstallDir = installDir
        .resolve(input.config.code.targetOS.name)
        .resolve(input.config.code.targetArchitecture.name);
    await xmake.install(
      target: target,
      installDir: platformInstallDir.toFilePath(),
    );

    final libDir = switch (input.config.code.targetOS) {
      .windows => platformInstallDir.resolve('bin').toFilePath(),
      _ => platformInstallDir.resolve('lib').toFilePath(),
    };

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: assetName,
        file: .file(
          await findLibraryFile(
            input.config.code.targetOS.libraryFileName(
              libHintName,
              DynamicLoadingBundled(),
            ),
            libDir,
          ),
        ),
        linkMode: DynamicLoadingBundled(),
      ),
    );
  }
}
