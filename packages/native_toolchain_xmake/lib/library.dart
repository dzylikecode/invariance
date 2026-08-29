import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:code_assets/code_assets.dart';
import 'package:logging/logging.dart';

import 'builder.dart';

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
      logger: logger,
    );

    await builder.run(input: input, output: output);
  }

  Future<void> link({
    required LinkInput input,
    required LinkOutputBuilder output,
    LinkerOptions? linkerOptions,
  }) async {
    final linker = CLinker.library(
      name: target,
      packageName: input.packageName,
      assetName: assetName,
    );
    final assets = input.assets.code.where((a) => a.id.endsWith(assetName));

    await linker.run(
      input: input,
      output: output,
      linkerOptions: linkerOptions,
      sources: assets.map((a) => a.file!.toFilePath()).toList(),
    );
  }
}
