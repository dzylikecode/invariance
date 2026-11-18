import 'package:code_assets/code_assets.dart';
import 'package:embed/src/native/xmake.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await xmakeLibrary.build(input: input, output: output);

      // Track Dart hook inputs; native package edits also require a version bump.
      output.dependencies.addAll([
        input.packageRoot.resolve('xmake.lua'),
        input.packageRoot.resolve('include/embed.h'),
        input.packageRoot.resolve('src/embed.c'),
        input.packageRoot.resolve('assets/file1.txt'),
        input.packageRoot.resolve('assets/fold1/file1.txt'),
        input.packageRoot.resolve('local/packages/e/embed/xmake.lua'),
        input.packageRoot.resolve('local/packages/e/embed/port/xmake.lua'),
      ]);
    }
  });
}
