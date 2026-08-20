import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final xmakeBuilder = await XmakeBuilder.create(
      project: input.packageRoot.toFilePath(),
      packageName: 'project_xmake',
      codeConfig: input.config.code,
    );

    await xmakeBuilder.config();
    await xmakeBuilder.build(target: 'project_xmake');
    final installedPath = await xmakeBuilder.install(target: 'project_xmake');

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/project_xmake.g.dart',
        file: .file(installedPath),
        linkMode: DynamicLoadingBundled(),
      ),
    );

    output.dependencies.add(input.packageRoot.resolve('xmake.lua'));
  });
}
