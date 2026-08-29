import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:project_xmake/src/xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      // flutter need to check this flag
      await xmakeLibrary.build(input: input, output: output);
    }
  });
}
