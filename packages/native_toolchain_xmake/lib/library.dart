import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

import 'builder.dart';
import 'linker.dart';

/// Controls whether xmake's build output goes through the Dart link hook.
enum LinkHookMode {
  /// Builds a static archive for the link hook. Requires linking to be enabled.
  always,

  /// Builds a shared library and bundles it directly with the app.
  never,

  /// Uses the link hook when the build enables linking.
  auto,
}

class XmakeLibrary({
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
  final String? libHintName,
  required final String assetName,
  final LinkHookMode linkHook = .auto,
  Logger? logger,
}) {
  final logger = logger ?? Logger('XmakeLibrary:$target')
    ..onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });

  /// [installDir] is the directory where the library will be installed, if null, use `$projectRoot/dist`
  Future<void> build({
    required BuildInput input,
    required BuildOutputBuilder output,
    Uri? installDir,
  }) async {
    final builder = XmakeBuilder(
      target: target,
      libHintName: libHintName,
      assetName: assetName,
      projectRoot: input.packageRoot,
      installDir: installDir,
      logger: logger,
      linkHook: linkHook,
    );

    await builder.run(input: input, output: output);
  }

  /// Links the shared target with [symbolsToKeep] as its `keep_symbols` option.
  ///
  /// An empty list skips linking and emits no code asset.
  Future<void> link({
    required LinkInput input,
    required LinkOutputBuilder output,
    required Iterable<String> symbolsToKeep,
  }) async {
    final linker = XmakeLinker(
      target: target,
      libHintName: libHintName,
      assetName: assetName,
      projectRoot: input.packageRoot,
      logger: logger,
    );

    await linker.run(
      input: input,
      output: output,
      symbolsToKeep: symbolsToKeep,
    );
  }
}
