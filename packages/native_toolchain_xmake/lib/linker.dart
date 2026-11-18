import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

import 'xmake.dart';

class XmakeLinker({
  required final String target,
  String? libHintName,
  required final String assetName,
  required final Uri projectRoot,
  final Uri? installDir,
  required final Logger logger,
}) {
  final libHintName = libHintName ?? target;

  Future<void> run({
    required LinkInput input,
    required LinkOutputBuilder output,
    required Iterable<String> symbolsToKeep,
  }) async {
    final symbols = symbolsToKeep.toList(growable: false);
    if (symbols.isEmpty) {
      logger.info('Skipping linking as no symbols are to be kept.');
      return;
    }

    if (!await hasXmake()) {
      throw Exception(
        'Xmake cannot be found in the system path. Please install xmake first or add it to the system path. '
        'See https://xmake.io/guide/quick-start.html for installation instructions.',
      );
    }

    final linkMode = DynamicLoadingBundled();

    final xmake = Xmake(
      projectRoot: projectRoot.toFilePath(),
      codeConfig: input.config.code,
      // The symbol list selects static package inputs for this shared output.
      kind: .shared,
      logger: logger,
    );

    // Configure the complete symbol list for this link invocation.
    await xmake.config(clean: true, symbolsToKeep: symbols);
    await xmake.build(target: target);
    final platformInstallDir = (installDir ?? input.outputDirectory)
        .resolveUri(.directory(input.config.code.targetOS.name))
        .resolveUri(.directory(input.config.code.targetArchitecture.name));

    await xmake.install(
      target: target,
      installDir: platformInstallDir.toFilePath(),
    );

    final libDir = platformInstallDir.resolveUri(
      .directory(switch (input.config.code.targetOS) {
        .windows => 'bin',
        _ => 'lib',
      }),
    );

    final libFile = await findLibraryFile(
      input.config.code.targetOS.libraryFileName(libHintName, linkMode),
      libDir.toFilePath(),
      kind: .shared,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: assetName,
        file: .file(libFile),
        linkMode: linkMode,
      ),
      routing: const ToAppBundle(),
    );

    logger.info('$assetName is associated with $libFile');

    output.dependencies.add(projectRoot.resolve('xmake.lua'));
    output.dependencies.addAll(
      input.assets.code
          .where(
            (asset) => asset.id == 'package:${input.packageName}/$assetName',
          )
          .map((asset) => asset.file)
          .whereType<Uri>(),
    );
  }
}
