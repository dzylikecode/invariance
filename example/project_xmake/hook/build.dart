import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:project_xmake/src/native/xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      // flutter need to check this flag
      await xmakeLibrary.build(input: input, output: output);
      output.dependencies.addAll([
        input.packageRoot.resolve('xmake.lua'),
        input.packageRoot.resolve('src/impl.cpp'),
        input.packageRoot.resolve('include/project_xmake.h'),
        input.packageRoot.resolve('local/packages/p/project_xmake/xmake.lua'),
        input.packageRoot.resolve(
          'local/packages/p/project_xmake/port/xmake.lua',
        ),
      ]);
    }
  });
}
