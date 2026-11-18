---
name: dart-xmake
description: >-
  Integrate C/C++ libraries into Dart and Flutter with native_toolchain_xmake,
  building on general Dart and Xmake skills. Use when connecting xmake targets
  to build/link hooks, generating matching FFI assets, organizing native
  integration files, or tree-shaking native code from Dart usage records.
---

# Dart native libraries with xmake

This skill builds on general Dart and Xmake knowledge. We recommend installing:

- [Dart skills](https://github.com/dart-lang/skills), also bundled in the
  [Dart and Flutter plugin](https://github.com/flutter/agent-plugins), for Dart
  workflows, FFI generation, hooks, analysis, and testing.
- [Xmake skills](https://github.com/xmake-io/xmake-skills) for targets, options,
  packages, rules, toolchains, and troubleshooting.

Use those skills for general workflows. This skill covers their integration:
`native_toolchain_xmake`, the `dart_native` rules, FFI asset registration, and
native tree shaking. Apply the integration and layout choices here when adapting
general FFI guidance; compilation and linking use `native_toolchain_xmake`.

Work in the Dart package that owns the native integration and reuse its existing
targets. The examples use the ffigen 22 Dart API; check resolved versions before
adapting the generator.

## Choose the build flow

| `linkHook` | Build output | Link hook |
| --- | --- | --- |
| `.never` | Complete shared library, routed to the app bundle | Not used |
| `.auto` | Static archive when linking is enabled; shared library otherwise | Used when linking is enabled |
| `.always` | Static archive, routed to the link hook | Requires a build with linking enabled |

Use `.never` for direct bundling. Use `.auto` with `hook/link.dart` for optional
native tree shaking. An archive sent to a link hook is an intermediate input;
the hook must explicitly emit the shared library that belongs in the bundle.

## Follow the integration order

1. **Prepare the native project.** Read
   [native-project.md](references/native-project.md) for the C ABI conventions,
   `dart_native` rules, package layout, and interaction with Dart hook caching.
2. **Connect Dart.** Read [build-hook.md](references/build-hook.md) for the
   recommended file layout, ffigen, the shared `XmakeLibrary` configuration, and
   `hook/build.dart`. Validate direct bundling with a small Dart caller.
3. **Add native tree shaking when needed.** Read
   [tree-shaking.md](references/tree-shaking.md) to route the complete archive
   through `hook/link.dart` and select native symbols from recorded Dart uses.
   This extends the build-hook setup; keep its bindings and shared config.

Read only the references needed for the current task. For an existing failure,
start with the stage that failed rather than rebuilding the whole integration.

## Preserve the contracts

- Keep the code asset registration consistent with the binding library's URI
  or explicit FFI asset ID. Pass strings directly where needed; separate
  `assetName` and `assetId` variables are not required.
- `target` names an xmake target, not a library filename. Set `libHintName` only
  when the installed library's base name differs; omit platform prefixes and
  extensions. On the package-based link path, both hooks use the same target.
- Keep C linkage and API visibility in the header. The `dart_native` rules
  prepare compilation, installation, and final linking; they do not define the
  project's API macros. Export filtering and code/data GC are separate steps.
- `symbolsToKeep` is required. Missing usage information
  (`recordedUses == null`) means preserving all symbols in the binding mapping.
  An empty selection means skipping xmake linking and emitting no code asset.
- A rerun of a Dart hook does not invalidate an installed native package with
  the same version. Refresh that package after native source, resource, or
  compilation-rule changes by changing its version or explicitly reinstalling.

## Verify the changed flow

Regenerate bindings after header or generator changes, then run static analysis
and the relevant caller or tests. For linking, build and run a CLI bundle:

```sh
dart build cli --target=bin/main.dart --output=build/cli
```

Check both an unused case and a case that calls one API. The unused case should
omit the native library; the used case should run and retain only its required
entrypoints and dependencies.

For a failed build, inspect the hook log's configure/build/install command.
For a missing library, compare the selected kind, installed filename, and
`libHintName`; a Windows import `.lib` is not the DLL. For an unresolved FFI
call, compare the binding URI, code asset ID, and exact exported C symbol.
