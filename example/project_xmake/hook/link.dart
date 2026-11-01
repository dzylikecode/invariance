import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';
import 'package:project_xmake/src/xmake.dart';
import 'package:project_xmake/src/project_xmake.record_use_mapping.g.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    final linkerOptions = LinkerOptions.treeshake(
      symbolsToKeep: input.recordedUses?.calls.keys.cast<Method>().map(
        (e) => recordUseMapping[e.name]!,
      ),
    );

    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: linkerOptions,
    );
  });
}
