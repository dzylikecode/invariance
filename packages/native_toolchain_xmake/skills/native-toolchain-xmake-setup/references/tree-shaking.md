# Tree-shake native symbols with a link hook

Start from the `example_native` C target in the main skill. Use Dart 3.13 or later and a build that supplies usage records, such as a Dart CLI AOT build. Keep `native_toolchain_xmake`, `hooks`, `code_assets`, `record_use`, and `meta` under `dependencies`. The link hook imports `record_use`, and the generated bindings import `meta`. Add `ffigen` as a dev dependency and make libclang available to the generator. The example uses the ffigen 22 Dart configuration API.

## Route the archive to the link hook

In `xmake.lua`, replace `set_kind("shared")` with `set_kind(get_config("kind") or "shared")`. `XmakeLibrary.build` supplies `--kind=static` when it routes the archive to the link hook and `--kind=shared` for direct bundling. Keep the example's `EXAMPLE_NATIVE_SHARED` define for Windows so its symbols can also be exported when the link hook turns the archive into a DLL without a symbol list.

Share the library configuration between both hooks in `lib/src/xmake_config.dart`:

```dart
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/example_native.g.dart';
const assetId = 'package:example_native/$assetName';

final xmakeLibrary = XmakeLibrary(
  target: 'example_native',
  assetName: assetName,
  linkHook: .auto,
);
```

In `hook/build.dart`, import `package:example_native/src/xmake_config.dart` and call `xmakeLibrary.build(input: input, output: output)` inside the existing `input.config.buildCodeAssets` check.

`.auto` follows the build's `linkingEnabled` flag. Use `.always` only when that flag is true for every build that uses the configuration. `.never` bundles xmake's shared library directly. On the link hook path, the static archive is the input to `XmakeLibrary.link`. The final link mode follows the link input's code asset preference.

## Generate bindings and the symbol mapping

Create `tool/ffigen.dart`:

```dart
import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final root = Platform.script.resolve('../');
  final header = root.resolve('include/example_native.h');
  await FfiGenerator(
    input: Input(entryPoints: [header], include: (uri) => uri == header),
    output: Output(
      dart: DartOutput(path: root.resolve('lib/src/example_native.g.dart')),
      recordUseMapping: root.resolve(
        'lib/src/example_native.record_use_mapping.g.dart',
      ),
    ),
    visitors: [
      Visitor(
        func: (node) {
          node.isIncluded = node.name == 'native_add';
          node.recordUse = node.isIncluded;
        },
      ),
    ],
  ).generate();
}
```

Run `dart run tool/ffigen.dart` from the package root. Regenerate both outputs together when the header or Dart binding names change. Call the generated `@Native` declarations so the compiler can record their use. If the package also finds symbols by name at runtime, explicitly keep those symbols or use the direct shared library path.

## Link the recorded symbols

Create `hook/link.dart`:

```dart
import 'package:code_assets/code_assets.dart';
import 'package:example_native/src/example_native.record_use_mapping.g.dart';
import 'package:example_native/src/xmake_config.dart';
import 'package:hooks/hooks.dart';
import 'package:record_use/record_use.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        !input.assets.code.any((asset) => asset.id == assetId)) {
      return;
    }

    final methods = input.recordedUses?.calls.keys.whereType<Method>();
    final symbolsToKeep = methods
        ?.where((method) => method.parent == const Library(assetId))
        .map((method) => recordUseMapping[method.name]!)
        .toSet();

    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: .treeshake(symbolsToKeep: symbolsToKeep),
    );
  });
}
```

The asset check allows the hook to return when the build routed the library directly to the app. The method filter selects top-level functions declared in the generated binding library. If you use a custom asset ID, filter by the actual Dart binding library URI separately from the asset ID.

Pass `null` through when usage records are absent so the link hook preserves all symbols. An empty set means the records contain no calls to this binding library, so `CLinker` omits the whole library. If unused functions remain, inspect how the compiler groups them into object files and sections. On Windows, an archive member pulled in for one symbol can also retain other symbols declared with `__declspec(dllexport)` in that member.

Run `dart build cli bin/main.dart` to exercise the link hook and recorded uses with the example's CLI entry point.
