# Generate bindings and bundle a shared library

Start with the `example_native` xmake target and `native_add` C API from
[native-project.md](native-project.md). Check that `xmake --version` runs in the
environment that launches Dart or Flutter. This reference uses
`native_toolchain_xmake` 0.1.0 or later and the ffigen 22 Dart configuration API.

Keep `native_toolchain_xmake`, `hooks`, `code_assets`, and `meta` under regular
`dependencies`. The generated bindings import `meta` for usage annotations even
when bundling directly. Add `ffigen: ^22.0.0` under `dev_dependencies` and make
libclang available to the generator.

## Organize the package

For a new integration, prefer this layout. Preserve an existing layout or the
user's chosen structure; adapt imports, generator outputs, and asset IDs
together rather than moving files just to match this recommendation.

```text
example_native/
├── lib/
│   ├── example_native.dart
│   └── src/native/
│       ├── example_native.g.dart
│       ├── example_native.record_use_mapping.g.dart
│       └── xmake.dart
├── hook/build.dart
├── tool/ffigen.dart
├── bin/main.dart
├── include/example_native.h
├── src/example_native.c
├── assets/                     # When the native build uses resources
├── local/                      # When it uses local xmake packages
└── xmake.lua
```

Keep package-owned native Dart implementation, generated bindings, the symbol
mapping, and shared xmake configuration in `lib/src/native/`. Keep the public API
in `lib/<package>.dart`. Make `hook/*.dart` thin entrypoints that share the
`XmakeLibrary` configuration; keep `tool/ffigen.dart` as the generator
entrypoint. Leave native headers, sources, resources, package recipes, and the
root build description in their existing locations.

## Configure the library

- `target` names the target in `xmake.lua`.
- `libHintName` overrides the installed library's base name when it differs from
  `target`. Omit the platform prefix and extension, such as `lib` and `.so`.
- `assetName` is the part after `package:<package_name>/` in the FFI asset ID.
  For this binding, use `src/native/example_native.g.dart`.
- The resulting code asset ID is
  `package:example_native/src/native/example_native.g.dart`. The default
  generated `@Native` asset ID is the binding library's URI. Exporting its
  declarations through the public barrel does not change that URI. If the
  binding sets `@DefaultAsset` or an explicit `assetId`, match that ID instead.

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

Let ffigen generate the `@Native` declarations and usage mapping rather than
maintaining manual declarations alongside them. Regenerate both outputs together
when the header or Dart binding names change. `node.recordUse = true` prepares the
bindings for the optional link-hook flow without changing direct bundling.

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

`.never` builds a shared library and bundles it directly. The xmake target must
install that library under the expected base name.

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

Track the inputs used by this build, including resources and local package
recipes or port scripts where present. These dependencies make Dart rerun the
hook when inputs change. Native package cache invalidation still follows the
version and reinstall rules in [native-project.md](native-project.md).

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
dart pub get
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
