# Tree-shake native symbols with a link hook

Start from the `example_native` C target in the main skill. Use Dart 3.13 or later and a build that supplies usage records, such as a Dart CLI AOT build. Keep `native_toolchain_xmake`, `hooks`, `code_assets`, `record_use`, and `meta` under `dependencies`. The link hook imports `record_use`, and the generated bindings import `meta`. Add `ffigen` as a dev dependency and make libclang available to the generator. The example uses the ffigen 22 Dart configuration API.

## Route the archive to the link hook

Package the native source target as an xmake package with static and shared
variants. In that source project, use
`add_rules("@dart_native/library", {kind = kind})`, where `kind` matches its
explicit `set_kind(kind)`. The native project manages its API macros: static
inputs to the final link must avoid forced `dllexport`, `used`, or `retain`
attributes that keep unused functions alive. API symbols must remain eligible
for export; a final export list cannot promote symbols compiled with hidden
visibility.

In the Dart package's `xmake.lua`, one target selects between installation and
final linking:

| Phase | `kind` | Symbols | Native package | Target behavior |
| --- | --- | --- | --- | --- |
| Build with linking enabled | `static` | Absent | Static | Phony, installs the complete archive |
| Build for direct bundling | `shared` | Absent | Shared | Phony, installs the complete shared package |
| Link | `shared` | Supplied | Static | Shared, selects exports and runs linker GC |

```lua
local outputKind = get_config("kind") or "static"
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})
option("keep_symbols")
    set_showmenu(true)
option_end()
local symbols = get_config("keep_symbols")
local linking = outputKind == "shared" and symbols
local packageKind = linking and "static" or outputKind

-- The package version selects a fixed remote rule source commit.
add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})
-- Register the repository containing the native package's own recipe too.
add_repositories("local-repo local", {rootdir = os.scriptdir()})
add_requires("example_native 1.0.0", {
    system = false,
    configs = {shared = packageKind == "shared", pic = true}
})

target("example_native")
    add_packages("example_native", "dart_native")
    if linking then
        set_kind("shared")
        add_rules("@dart_native/link", {symbols = symbols})
    else
        set_kind("phony")
        add_rules("@dart_native/install", {package = "example_native"})
    end
```

`outputKind` is the final library type. `linking` selects whether to link and
trim it, and `packageKind` is the input package type. The install rule copies the
selected package into the target's install directory. The link rule handles archive extraction, platform export lists,
and linker GC; the target still sets its kind and package dependencies.
`get_config("keep_symbols")` passes the serialized Lua table literal to the rule,
which restores the table with `string.deserialize`. The Dart binding mapping
supplies native symbol names. The option has no default: build configuration
needs no symbols, while the same target becomes shared for the link phase.
The native package stays static when symbols are supplied, even though the
final target is shared. See `example/project_xmake/xmake.lua` and its local
package for a complete setup. That example explicitly sets
`configs = {local_source = true}` in both its root and native source projects.
The snippet above uses the default remote rules. See the main skill for source
selection and immutable rule version handling.

Share the library configuration between both hooks in `lib/src/native/xmake.dart`:

```dart
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/native/example_native.g.dart';
const assetId = 'package:example_native/$assetName';

final xmakeLibrary = XmakeLibrary(
  target: 'example_native',
  libHintName: 'example_native',
  assetName: assetName,
  linkHook: .auto,
);
```

In `hook/build.dart`, import `package:example_native/src/native/xmake.dart` and call `xmakeLibrary.build(input: input, output: output)` inside the existing `input.config.buildCodeAssets` check.

`.auto` follows the build's `linkingEnabled` flag. Use `.always` only when that
flag is true for every build that uses the configuration. When linking is
disabled or `.never` is selected, the build hook still uses `target`, with
`--kind=shared`, to install the full shared package. On the link hook path,
the build hook configures `--kind=static` to install the complete archive.
`XmakeLibrary.link` configures `--kind=shared`, passes the selected symbols to
the same target, and emits a `DynamicLoadingBundled` code asset. The package's
`configs.shared = packageKind == "shared"` keeps its inputs static
for this final link.

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
import 'package:example_native/src/native/example_native.record_use_mapping.g.dart';
import 'package:example_native/src/native/xmake.dart';
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
        .toSet() ?? recordUseMapping.values.toSet();

    await xmakeLibrary.link(
      input: input,
      output: output,
      symbolsToKeep: symbolsToKeep,
    );
  });
}
```

The asset check allows the hook to return when the build routed the library directly to the app. The method filter selects top-level functions declared in the generated binding library. If you use a custom asset ID, filter by the actual Dart binding library URI separately from the asset ID.

`symbolsToKeep` is required. When usage records are absent, select all values
from the Dart binding mapping before calling the linker. An empty set means the
records contain no calls to this binding library, so `XmakeLinker` omits the whole library. If unused
functions remain, inspect the xmake target's export control and how the compiler
groups functions into object files and sections.

Run `dart build cli bin/main.dart` to exercise the link hook and recorded uses with the example's CLI entry point.
