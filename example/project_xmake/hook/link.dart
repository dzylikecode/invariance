// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:record_use/record_use.dart';
import 'package:project_xmake/src/xmake.dart';
import 'package:project_xmake/src/project_xmake.record_use_mapping.g.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    if (!input.assets.code.any((asset) => asset.id == assetId)) return;
    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: .treeshake(
        flags: switch (input.config.code.targetOS) {
          OS.linux => ['-z,defs', '-lstdc++'],
          OS.macOS || OS.iOS => ['-lc++'],
          _ => [],
        },
        symbolsToKeep: input.recordedUses?.calls.keys
            .whereType<Method>()
            .where((method) => method.library.uri == assetId)
            .map((method) => recordUseMapping[method.name]!),
      ),
    );
  });
}
