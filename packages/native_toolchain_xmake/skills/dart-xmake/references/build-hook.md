# Generate bindings and bundle a shared library

Start with the `example_native` xmake target and `native_add` C API from
[native-project.md](native-project.md). Apply the general Dart asset workflow
with `native_toolchain_xmake` 0.2.0 or later as its backend. The generator below
uses the ffigen 22 visitor API.

Keep `native_toolchain_xmake`, `hooks`, `code_assets`, and `meta` under regular
`dependencies`; generated usage annotations need `meta` even when bundling
directly. Add `ffigen: ^22.0.0` under `dev_dependencies`.

## Use the package layout

For new integrations, prefer this layout:

```text
example_native/
├── lib/
│   ├── example_native.dart
│   └── src/native/
│       ├── example_native.g.dart
│       ├── example_native.record_use_mapping.g.dart
│       └── xmake.dart
├── hook/
│   ├── build.dart
│   └── link.dart               # When native tree shaking is enabled
├── tool/ffigen.dart
├── bin/main.dart
├── include/example_native.h
├── src/example_native.c
├── assets/                     # When the native build uses resources
├── local/                      # When it uses local xmake packages
└── xmake.lua
```

Keep generated bindings, their symbol mapping, and shared xmake configuration
in `lib/src/native/`, with thin `hook/*.dart` entrypoints and the public API in
`lib/example_native.dart`. Adapt an existing layout by changing imports,
generator outputs, and asset IDs together.

## Match the FFI asset

`assetName: 'src/native/example_native.g.dart'` produces the code asset ID
`package:example_native/src/native/example_native.g.dart`. It must match the
generated `@Native` asset ID, which defaults to the binding library's URI.
Exporting declarations through the public barrel does not change that URI. If
the binding uses `@DefaultAsset` or an explicit `assetId`, match that ID instead.

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
      dart: DartOutput(path: root.resolve('lib/src/native/example_native.g.dart')),
      recordUseMapping: root.resolve(
        'lib/src/native/example_native.record_use_mapping.g.dart',
      ),
    ),
    visitors: [
      Visitor(
        func: (node) {
          node.isIncluded = true;
          node.recordUse = true;
        },
      ),
    ],
  ).generate();
}
```

Regenerate the bindings and mapping together when the header or Dart binding
names change. `node.recordUse = true` enables the optional link-hook flow while
also supporting direct bundling.

## Share the build configuration

Create `lib/src/native/xmake.dart`:

```dart
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

final xmakeLibrary = XmakeLibrary(
  target: 'example_native',
  assetName: 'src/native/example_native.g.dart',
  linkHook: .never,
);
```

`.never` builds and bundles the complete shared library directly. The target
must install the library; if its base name differs from `target`, set
`libHintName` without the platform prefix or extension.

Create `hook/build.dart`:

```dart
import 'package:code_assets/code_assets.dart';
import 'package:example_native/src/native/xmake.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await xmakeLibrary.build(input: input, output: output);

      output.dependencies.addAll([
        input.packageRoot.resolve('xmake.lua'),
        input.packageRoot.resolve('include/example_native.h'),
        input.packageRoot.resolve('src/example_native.c'),
      ]);
    }
  });
}
```

Add resources, local package recipes, and port scripts to `output.dependencies`
when the build uses them. This reruns the Dart hook on changes; it does not
invalidate xmake's installed-package cache. Apply the version/reinstall rules
in [native-project.md](native-project.md).

## Expose and run the API

Create the public barrel `lib/example_native.dart`:

```dart
export 'src/native/example_native.g.dart';
```

Create `bin/main.dart`:

```dart
import 'package:example_native/example_native.dart';

void main() {
  print(native_add(2, 3));
}
```

Run from the package root:

```sh
dart run tool/ffigen.dart
dart run bin/main.dart
dart analyze
```

The program prints `5`. Extend this working direct-build path with
[tree-shaking.md](tree-shaking.md) when the package needs native linker GC.

If a library cannot be found after installation, compare `target`,
`libHintName`, and the installed filename. The default lookup is under
`dist/<target-os>/<target-arch>/bin/` for Windows DLLs and
`dist/<target-os>/<target-arch>/lib/` for other libraries. A Windows `.lib` may be
an import library, so verify the actual DLL exists. If Dart cannot resolve the
asset, compare its ID with the binding URI; if only a symbol is missing, check
its exact exported name and C linkage.
