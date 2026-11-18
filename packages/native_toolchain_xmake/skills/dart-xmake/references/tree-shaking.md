# Add a link hook for native tree shaking

Start with the generated bindings, shared `xmake.dart`, and build hook in
[build-hook.md](build-hook.md). Use Dart 3.13 or later and a build that enables
linking and supplies usage records, such as `dart build cli`. Add `record_use`
as a regular dependency. The bindings already use `meta.RecordUse` and generate
their symbol mapping.

## Select installation or final linking in xmake

The native package described in [native-project.md](native-project.md) must
support static and shared builds. In the Dart package's root `xmake.lua`, use
one target for both hooks:

| Phase | `kind` | Symbols | Package input | Root target |
| --- | --- | --- | --- | --- |
| Build with linking | `static` | Absent | Static | Phony, installs the complete archive |
| Build for direct bundling | `shared` | Absent | Shared | Phony, installs the complete shared library |
| Link | `shared` | Supplied | Static | Shared, selects exports and runs GC |

```lua
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})
option("keep_symbols", {
    description = "Lua table of native symbols supplied by Dart"
})

local outputKind = get_config("kind") or "static"
local symbols = get_config("keep_symbols")
local linking = outputKind == "shared" and symbols
local packageKind = linking and "static" or outputKind

add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})
add_repositories("local-repo local", {rootdir = os.scriptdir()})
add_requires("example_native 1.0.0", {
    system = false,
    configs = {shared = packageKind == "shared"}
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

Give `keep_symbols` no default. Dart sends a Lua table literal string such as
`{"native_add"}`; the link rule restores it with `string.deserialize`. The
shared output uses static package inputs when symbols are supplied. The install
rule copies the selected package into the target's install directory; the link
rule handles archive extraction, export lists, and linker GC. The library rule
already prepares PIC where required, so no extra package `pic` config is needed
for this source project.

Choose remote or local rules consistently in both projects, as described in
[native-project.md](native-project.md). In this repository, `project_xmake` and
`embed` use local rules; `template_adapter` exercises the remote source through
the public index.

## Connect the recorded uses

Change `linkHook` to `.auto` in `lib/src/native/xmake.dart`. Keep the same target,
asset name, and asset ID for both hooks. The build hook will emit a complete
static archive with `ToLinkHook` when linking is enabled; otherwise it bundles
the complete shared library directly. Use `.always` only when every build of
the integration enables linking.

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

    final symbols = input.recordedUses?.calls.keys
        .whereType<Method>()
        .where((method) => method.library.uri == assetId)
        .map((method) => recordUseMapping[method.name]!);

    await xmakeLibrary.link(
      input: input,
      output: output,
      symbolsToKeep: symbols ?? recordUseMapping.values,
    );
  });
}
```

The filter uses the generated binding library's URI. If the FFI bindings specify
a different explicit asset ID, filter by their actual Dart library URI while
using the explicit ID for the asset check and shared configuration.

`symbolsToKeep` is required; its two boundary cases have different meanings:

- `recordedUses == null`: no analysis information is available. Preserve every
  native symbol in `recordUseMapping.values`.
- An empty selection: the records contain no uses of this binding library.
  `XmakeLinker` returns before invoking xmake and emits no `CodeAsset`, so there
  is no native library in the bundle. The build-stage archive may still exist
  in the build directory or cache.

Nonempty selections run the shared link and emit a `DynamicLoadingBundled`
asset routed to `ToAppBundle`. Call generated FFI functions directly from
reachable Dart code so their uses are recorded. When wrapping resources in
`const` descriptors, keep direct FFI calls inside ordinary loader functions:
storing native function tear-offs directly in constant fields can miss usage
records in Dart 3.14. Explicitly keep symbols looked up by runtime strings.

## Verify removal, not just hidden exports

Build and run an unused caller and a caller that uses one entrypoint:

```sh
dart build cli --target=bin/main.dart --output=build/cli
```

Check that the unused bundle contains no library, and that the used bundle runs
with the expected exports. Inspect the regular symbol table or distinctive
resource bytes to prove unused code/data was removed. For that inspection, keep
the link target's regular symbol table with `set_strip("none")`; platform symbol
tools and flags differ. Use an actual build test when validating wrappers, since
recorded uses depend on compiler reachability analysis.
