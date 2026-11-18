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

This command runs the following platform-specific installers:

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

## xmake

- [xmake and Dart hooks](../../example/project_xmake/)
- [Embed resource files](../../example/embed_text/)

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
