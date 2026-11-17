import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await XmakeLibrary(
        target: 'embed_text',
        assetName: 'src/third_party/embed_text.g.dart',
        linkHook: .never,
      ).build(input: input, output: output);

      // Resource edits must invalidate the Dart build hook as well as xmake.
      output.dependencies.addAll([
        input.packageRoot.resolve('xmake.lua'),
        input.packageRoot.resolve('src/embed_text.h'),
        input.packageRoot.resolve('src/embed_text.c'),
        input.packageRoot.resolve('resources/message.txt'),
      ]);
    }
  });
}
