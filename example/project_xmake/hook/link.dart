import 'package:hooks/hooks.dart';
import 'package:record_use/record_use.dart';
import 'package:project_xmake/src/project_xmake.record_use_mapping.g.dart';
import 'package:project_xmake/src/xmake.dart';

void main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: .treeshake(
        symbolsToKeep: input.recordedUses?.calls.keys.cast<Method>().map(
          (e) => recordUseMapping[e.name]!,
        ),
      ),
    );
  });
}
