import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

import 'xmake.dart';
import 'library.dart';

class XmakeBuilder({
  required final String target,
  String? libHintName,
  required final String assetName,
  required final Uri projectRoot,
  Uri? installDir,
  required final Logger logger,
  required final LinkHookMode linkHook,
}) {
  final libHintName = libHintName ?? target;
  final installDir = installDir ?? projectRoot.resolveUri(.directory('dist'));

  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
  }) async {
    if (!await hasXmake()) {
      throw Exception(
        'Xmake cannot be found in the system path. Please install xmake first or add it to the system path. '
        'See https://xmake.io/guide/quick-start.html for installation instructions.',
      );
    }

    final useLinkHook = switch (linkHook) {
      .always => true,
      .never => false,
      .auto => input.config.linkingEnabled,
    };

    final linkMode = useLinkHook ? StaticLinking() : DynamicLoadingBundled();
    final Kind kind = useLinkHook ? .static : .shared;

    logger.info('xmake library kind: $kind, use link hook: $useLinkHook');

    final xmake = Xmake(
      projectRoot: projectRoot.toFilePath(),
      codeConfig: input.config.code,
      kind: kind,
      logger: logger,
    );

    await xmake.config();
    await xmake.build(target: target);
    final platformInstallDir = installDir
        .resolveUri(.directory(input.config.code.targetOS.name))
        .resolveUri(.directory(input.config.code.targetArchitecture.name));

    await xmake.install(
      target: target,
      installDir: platformInstallDir.toFilePath(),
    );

    final libDir = platformInstallDir.resolveUri(
      .directory(switch ((input.config.code.targetOS, kind)) {
        (.windows, .shared) => 'bin',
        _ => 'lib',
      }),
    );

    final libFile = await findLibraryFile(
      input.config.code.targetOS.libraryFileName(libHintName, linkMode),
      libDir.toFilePath(),
      kind: kind,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: assetName,
        file: .file(libFile),
        linkMode: linkMode,
      ),
      routing: useLinkHook
          ? ToLinkHook(input.packageName)
          : const ToAppBundle(),
    );

    logger.info('$assetName is associated with $libFile');

    // TODO: add deps
  }
}
