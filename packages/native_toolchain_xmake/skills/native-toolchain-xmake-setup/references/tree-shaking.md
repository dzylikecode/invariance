# Tree-shake native symbols with a link hook

Start from the `example_native` C target in the main skill. Use Dart 3.13 or later and a build that supplies usage records, such as a Dart CLI AOT build. Keep `native_toolchain_xmake`, `hooks`, `code_assets`, `record_use`, and `meta` under `dependencies`. The link hook imports `record_use`, and the generated bindings import `meta`. Add `ffigen` as a dev dependency and make libclang available to the generator. The example uses the ffigen 22 Dart configuration API.

## Route the archive to the link hook

In `xmake.lua`, provide a build target that installs the package variant selected
by `--kind` (`configs.shared = get_config("kind") == "shared"`) and a separate
target with `set_kind("shared")` that accepts `keep_symbols`. The shared target is
responsible for archive extraction, export control, and linker GC. On Windows,
compile the archive without forced DLL exports and export the selected symbols
when linking the shared target. See `example/project_xmake/xmake.lua` for the
two-target setup and its local package.

Share the library configuration between both hooks in `lib/src/xmake_config.dart`:

```dart
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/example_native.g.dart';
const assetId = 'package:example_native/$assetName';

final xmakeLibrary = XmakeLibrary(
  target: 'example_native_build',
  linkTarget: 'example_native',
  libHintName: 'example_native',
  assetName: assetName,
  linkHook: .auto,
);
```

In `hook/build.dart`, import `package:example_native/src/xmake_config.dart` and call `xmakeLibrary.build(input: input, output: output)` inside the existing `input.config.buildCodeAssets` check.

`.auto` follows the build's `linkingEnabled` flag. Use `.always` only when that
flag is true for every build that uses the configuration. When linking is
disabled or `.never` is selected, the build hook still uses `target`, with
`--kind=shared`, to install the full shared package. On the link hook path,
the build hook configures `--kind=static` to install the complete archive.
`XmakeLibrary.link` also configures `--kind=static` to retain static package
inputs, passes the selected symbols to the explicitly shared `linkTarget`, and
emits a `DynamicLoadingBundled` code asset.

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
        ?.where((method) => method.library.uri == assetId)
        .map((method) => recordUseMapping[method.name]!)
        .toSet();

    await xmakeLibrary.link(
      input: input,
      output: output,
      symbolsToKeep: symbolsToKeep,
    );
  });
}
```

The asset check allows the hook to return when the build routed the library directly to the app. The method filter selects top-level functions declared in the generated binding library. If you use a custom asset ID, filter by the actual Dart binding library URI separately from the asset ID.

Pass `null` through when usage records are absent so the link hook restores the
xmake project's default export list. An empty set means the records contain no
calls to this binding library, so `XmakeLinker` omits the whole library. If unused
functions remain, inspect the xmake target's export control and how the compiler
groups functions into object files and sections.

Run `dart build cli bin/main.dart` to exercise the link hook and recorded uses with the example's CLI entry point.
