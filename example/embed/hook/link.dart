import 'package:code_assets/code_assets.dart';
import 'package:embed/src/third_party/embed.record_use_mapping.g.dart';
import 'package:embed/src/xmake.dart';
import 'package:hooks/hooks.dart';
import 'package:record_use/record_use.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    if (!input.assets.code.any((asset) => asset.id == assetId)) return;
    await xmakeLibrary.link(
      input: input,
      output: output,
      symbolsToKeep:
          input.recordedUses?.calls.keys
              .whereType<Method>()
              .where((method) => method.library.uri == assetId)
              .map((method) => recordUseMapping[method.name]!) ??
          recordUseMapping.values,
    );
  });
}
