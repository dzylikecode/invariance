---
name: native-toolchain-xmake-setup
description: >-
  Set up or troubleshoot Dart and Flutter native assets built with
  native_toolchain_xmake. Use when connecting an xmake.lua target to
  XmakeLibrary build or link hooks, matching FFI asset IDs, or enabling
  native tree shaking from Dart usage records.
---

# Build Dart native assets with xmake

Work in the Dart package that owns `xmake.lua`, the hooks, and the FFI bindings. Check that `xmake --version` runs in the environment that invokes Dart or Flutter. Add `native_toolchain_xmake`, `hooks`, and `code_assets` as regular dependencies if the package's hooks import them. These examples use the `linkHook` API introduced in `native_toolchain_xmake` 0.1.0. Check the resolved version before adapting an older integration.

## Choose a build path

- Use `linkHook: .never` to build and bundle a shared library directly. Start here for a package that only needs FFI bindings and a bundled library.
- Use `linkHook: .auto` (the default) with a `hook/link.dart` when the package supports tree shaking. When the build enables linking, xmake produces a static archive for the link hook. Otherwise it produces a shared library for direct bundling. Use `.always` only when the build is known to enable linking. Follow [the tree-shaking setup](references/tree-shaking.md) to connect Dart usage records to native symbols.

## Match the target and asset names

- `target` is the target declared in `xmake.lua`. Set `libHintName` to the library's base name without the platform prefix or extension if xmake installs it under a different name.
- `assetName` is the part after `package:<package_name>/` in the FFI asset ID. For `lib/src/example_native.g.dart` in package `example_native`, use `assetName: 'src/example_native.g.dart'`. The default `@Native` asset ID is the binding library's URI. If the binding sets `@DefaultAsset` or an explicit `assetId`, match that ID instead.

## Bundle a shared library

This minimal example uses package `example_native` and exports one C function. Adapt the names together when using it in another package.

### `xmake.lua`

```lua
target("example_native")
    set_kind("shared")
    add_includedirs("include")
    add_defines("EXAMPLE_NATIVE_SHARED")
    add_files("src/example_native.c")
```

### `include/example_native.h`

```c
#ifndef EXAMPLE_NATIVE_H
#define EXAMPLE_NATIVE_H

#include <stdint.h>

#if defined(_WIN32) && defined(EXAMPLE_NATIVE_SHARED)
#define EXAMPLE_NATIVE_API __declspec(dllexport)
#else
#define EXAMPLE_NATIVE_API
#endif

EXAMPLE_NATIVE_API int32_t native_add(int32_t a, int32_t b);

#endif
```

### `src/example_native.c`

```c
#include "example_native.h"

int32_t native_add(int32_t a, int32_t b) {
  return a + b;
}
```

### `hook/build.dart`

```dart
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await XmakeLibrary(
        target: 'example_native',
        assetName: 'src/example_native.g.dart',
        linkHook: .never,
      ).build(input: input, output: output);
    }
  });
}
```

### `lib/src/example_native.g.dart`

This binding can also be generated with ffigen.

```dart
import 'dart:ffi';

@Native<Int32 Function(Int32, Int32)>()
external int native_add(int a, int b);
```

### `bin/main.dart`

```dart
import 'package:example_native/src/example_native.g.dart';

void main() {
  print(native_add(2, 3));
}
```

Run `dart run bin/main.dart` from the package root. The program prints `5`.

## Diagnose build and FFI errors

- If xmake cannot be started, check `PATH` in the process that launches Dart or Flutter. If it starts and fails, use the hook log to identify which configure, build, or install command failed.
- If the hook cannot find a library after installation, check the target's `set_kind(...)`, the file's base name and `libHintName`, and the actual installation directory. By default the builder looks under `dist/<target-os>/<target-arch>/bin/` for a Windows DLL and under `dist/<target-os>/<target-arch>/lib/` for other libraries. A Windows `.lib` can be an import library, so verify that the actual DLL or static archive exists for the chosen build path.
- If Dart cannot resolve an asset, compare the binding's asset ID with `package:<package_name>/<assetName>`. If it resolves the asset but cannot find a symbol, verify the exact exported symbol name and visibility. Use C linkage for a C ABI implemented in C++, and check the link hook's symbol list if tree shaking is enabled.
