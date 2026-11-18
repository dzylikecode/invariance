import 'package:code_assets/code_assets.dart';
import 'package:embed_text/src/xmake.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await xmakeLibrary.build(input: input, output: output);

      // Track Dart hook inputs; native package edits also require a version bump.
      output.dependencies.addAll([
        input.packageRoot.resolve('xmake.lua'),
        input.packageRoot.resolve('include/embed_text.h'),
        input.packageRoot.resolve('src/embed_text.c'),
        input.packageRoot.resolve('resources/message.txt'),
        input.packageRoot.resolve('local/packages/e/embed_text/xmake.lua'),
        input.packageRoot.resolve('local/packages/e/embed_text/port/xmake.lua'),
      ]);
    }
  });
}
