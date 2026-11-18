# xmake

[English](README.md) | [中文](README_zh.md)

## Why xmake instead of CMake?

- I think it had something to do with how `compile_commands.json` is generated.
- I like commands such as `dart run hello_world`. With xmake, I can use `xmake run hello_world` in much the same way.

## Prerequisites

### 1. Install xmake

```bash
dart run native_toolchain_xmake:install
```

You can also install xmake manually:

- Windows

  ```powershell
  irm https://xmake.io/psget.text | iex
  ```

- Linux

  ```bash
  curl -fsSL https://xmake.io/shget.text | bash
  ```

  Or:

  ```bash
  wget https://xmake.io/shget.text -O - | bash
  ```

- macOS

  ```bash
  brew install xmake
  ```

  > [!NOTE]
  > The official Bash installer can result in library lookup errors on macOS.

### 2. Install Zig for cross-compilation

This package uses Zig by default for cross-compilation. See the [Zig installation guide](https://ziglang.org/learn/getting-started/#managers).

- Windows

  ```powershell
  winget install -e --id zig.zig
  ```

- macOS

  ```bash
  brew install zig
  ```

## Agent skill

```bash
dart run skills@ get -p native_toolchain_xmake
```

## Examples

```dart
// build.dart
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      // Flutter requires this check.
      await XmakeLibrary(
        target: 'project_xmake',
        libHintName: 'project_xmake',
        assetName: 'src/project_xmake.g.dart',
      ).build(input: input, output: output);
    }
  });
}
```

```dart
// link.dart
void main(List<String> args) async {
  await link(args, (input, output) async {
    await XmakeLibrary(
      target: 'project_xmake',
      libHintName: 'project_xmake',
      assetName: 'src/project_xmake.g.dart',
    ).link(
      input: input,
      output: output,
      symbolsToKeep: input.recordedUses?.calls.keys.cast<Method>().map(
        (e) => recordUseMapping[e.name]!,
      ) ?? recordUseMapping.values,
    );
  });
}
```

## xmake notes

`build` and `link` invoke the same `target`. Its configuration selects one of
three paths:

| Phase | `kind` | `keep_symbols` | Native package | Target behavior |
| --- | --- | --- | --- | --- |
| Build with linking enabled | `static` | Absent | Static | Phony target installs the full archive |
| Build for direct bundling | `shared` | Absent | Shared | Phony target installs the full shared library |
| Link | `shared` | Supplied | Static | Shared target links and trims the final library |

`symbolsToKeep` is a required list; an empty
list skips the library. When usage records are unavailable, the Dart hook passes
`recordUseMapping.values` to keep all bound APIs. Link outputs are installed
under the hook output directory by default.

Dart passes `keep_symbols` as a Lua table literal string, for example
`{"add","subtract"}`. The link rule uses `string.deserialize` to restore the
table; the Dart binding mapping supplies the native symbol names.

### Share native build rules with `dart_native`

The xmake rule package `dart_native 1.0.0` downloads its rule sources from a
fixed Git commit by default. Register the repository and require the version in
each xmake project using the rules:

```lua
add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})
```

The three rules cover the native source project and one target used by both
hooks. In the native source project:

```lua
local kind = get_config("kind") or "static"
target("foo")
    set_kind(kind)
    add_packages("dart_native")
    add_rules("@dart_native/library", {kind = kind})
    add_files("src/*.c")
```

In the project consumed by the Dart hooks:

```lua
local outputKind = get_config("kind") or "static"
option("keep_symbols")
    set_showmenu(true)
option_end()

local symbols = get_config("keep_symbols")
local linking = outputKind == "shared" and symbols
local packageKind = linking and "static" or outputKind
add_requires("foo 1.0.0", {
    system = false,
    configs = {shared = packageKind == "shared", pic = true}
})

target("foo")
    add_packages("foo", "dart_native")
    if linking then
        set_kind("shared")
        add_rules("@dart_native/link", {symbols = symbols})
    else
        set_kind("phony")
        add_rules("@dart_native/install", {package = "foo"})
    end
```

`outputKind` is the final library type. `linking` selects whether to link and
trim it, and `packageKind` is the input package type. The native package must provide
both static and shared variants; the trimmed link selects its static variant.
`keep_symbols` has no default; the same target becomes a real shared target only
for a shared link with symbols. The library rule
prepares functions and data for section GC, the install rule installs the
selected package, and the link rule controls the final shared library's exports
and GC. C API macros remain the native project's responsibility: avoid forced
`dllexport` or retention attributes on the static inputs to the link hook.

Use `target: 'foo'` in `XmakeLibrary` for both hooks.

The public recipe at `packages/d/dart_native/xmake.lua` maps `1.0.0` to commit
`c241d2c9efcf6fbd1ab5d47614cb8614fec14fc2` of the invariance Git repository.
Callers specify the version; the recipe supplies the source commit. Keep a
published version's mapping unchanged and publish a new version for another
source commit.

For rule development in this checkout, `local_source` is a custom package
option that selects `packages/native_toolchain_xmake/xmake/` instead:

```lua
add_repositories("dart-native ../..", {rootdir = os.scriptdir()})
add_requires("dart_native 1.0.0", {
    system = false,
    configs = {local_source = true}
})
```

The relative path above applies to `example/foo/`; adapt it for another layout.
Both the consuming project and the native source project must opt in. The
`project_xmake` and `embed_text` examples use this local mode; `template_adapter`
uses the current index with the default remote source. Local edits require a
development version bump or explicit package reinstallation to refresh xmake's
cache.
Changes to the library compilation rule also require rebuilding the native
package; bump its version or force its reinstallation to replace existing archives.

The xmake workflow is configure → build → install.

### Configuration

Android:

```bash
xmake f --plat=android --arch=x86_64 --toolchain=ndk --ndk="C:/Users/<you>/AppData/Local/Android/Sdk/ndk/<version>" --mode=release --kind=shared -y
```

Windows:

```bash
xmake f --plat=windows --arch=x64 --mode=release --kind=shared -y
```

## Development

For coding agents:

- Keep the English and Chinese READMEs in sync.

## Issues

- [x] [Hooks lose environment variables](https://github.com/dart-lang/native/issues/3304)
- [x] [Cross-compilation issue](https://github.com/dart-lang/sdk/issues/63953)
- [x] [Tree shaking fails on Windows](https://github.com/dart-lang/native/pull/3773)
- [x] Cross-compiling with tree shaking still needs validation, including Zig toolchain compatibility.

### Known issue

If the network connection drops while xmake is downloading a tool during debugging, a child process such as `curl` may keep running and hold files open.

Use the following command to investigate, then stop the affected processes:

```bash
xmake -vD
```
