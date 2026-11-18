# Prepare the native project

Keep an existing usable xmake target. The example below compiles one C API
directly; the package variant later in this document lets other xmake projects
consume the same library and supports the archive-to-shared link flow.

## Use the published rules

The `dart_native` rule package provides `library`, `install`, and `link` rules.
For normal use, register the public repository and require its version:

```lua
add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})
```

The version selects a fixed Git source commit. Attach `dart_native` with
`add_packages` to each target that uses its rules.

## Define a C ABI

For package-owned headers, prefer `#pragma once`, separate C linkage from symbol
visibility, and compose both in the API macro on each public function. Preserve
an existing header convention when adapting a library. Keep the manually
indented preprocessor region between clang-format off/on markers.

`include/example_native.h`:

```c
#pragma once

#include <stdint.h>

// clang-format off
#ifdef __cplusplus
#  define EXAMPLE_NATIVE_EXTERN_C extern "C"
#else
#  define EXAMPLE_NATIVE_EXTERN_C extern
#endif

#if defined(_WIN32)
#  if defined(EXAMPLE_NATIVE_STATIC)
#    define EXAMPLE_NATIVE_EXPORT
#  elif defined(EXAMPLE_NATIVE_BUILD)
#    define EXAMPLE_NATIVE_EXPORT __declspec(dllexport)
#  else
#    define EXAMPLE_NATIVE_EXPORT __declspec(dllimport)
#  endif
#else
#  define EXAMPLE_NATIVE_EXPORT __attribute__((visibility("default")))
#endif
// clang-format on

#define EXAMPLE_NATIVE_API EXAMPLE_NATIVE_EXTERN_C EXAMPLE_NATIVE_EXPORT

EXAMPLE_NATIVE_API int32_t native_add(int32_t a, int32_t b);
```

`src/example_native.c`:

```c
#include "example_native.h"

int32_t native_add(int32_t a, int32_t b) {
  return a + b;
}
```

The linkage macro avoids an outer `extern "C"` block. Define the build macro
only while building the shared library, and publish the static macro to static
consumers. Adapt the prefix and macro names to the project.

## Compile static or shared

`xmake.lua`:

```lua
set_project("example_native")
set_languages("c11")
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

local kind = get_config("kind") or "shared"
add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})

target("example_native")
    set_kind(kind)
    add_packages("dart_native")
    add_rules("@dart_native/library", {kind = kind})
    add_files("src/**.c")
    add_includedirs("include", {public = true})
    add_headerfiles("include/(**.h)")
    if kind == "static" then
        add_defines("EXAMPLE_NATIVE_STATIC", {public = true})
    else
        add_defines("EXAMPLE_NATIVE_BUILD")
    end
```

The rule's `kind` must match `set_kind`. Static compilation prepares code/data
sections and platform relocation requirements for later GC. Shared compilation
prepares the library for bundling, including install-name header space on Apple
platforms. Keep API macro ownership in the project, outside the rule.

## Put compilation in a reusable package

For package-owned compilation, keep `include/`, `src/`, and resources at the
package root. Put the source project at
`local/packages/e/example_native/port/xmake.lua`. Reuse the compilation target
above, but resolve its inputs against the package root:

```lua
local sourceRoot = path.absolute("../../../../..", os.scriptdir())
-- Inside the compilation target:
add_files(path.join(sourceRoot, "src/**.c"))
add_includedirs(path.join(sourceRoot, "include"), {public = true})
add_headerfiles(path.join(sourceRoot, "include/(**.h)"))
```

The adjacent `local/packages/e/example_native/xmake.lua` recipe delegates to that
source project and publishes the static macro in package metadata:

```lua
package("example_native")
    set_sourcedir(path.join(os.scriptdir(), "port"))

    on_load(function(package)
        if not package:config("shared") then
            package:add("defines", "EXAMPLE_NATIVE_STATIC")
        end
    end)

    on_install(function(package)
        import("package.tools.xmake").install(package)
    end)
```

If the implementation is C++, publish its required runtime/system link
dependencies too, so C consumers can link it. In the invariance repository,
`example/project_xmake/local/packages/p/project_xmake/` shows this case.

Replace the Dart package's root compilation target with the package install/link
selector in [tree-shaking.md](tree-shaking.md). The source target still owns
compilation; the root target installs its finished library or links its archive.
Native functions must remain available for that final export selection. Avoid
forced DLL exports or `used`/`retain` attributes in static inputs, and do not
compile desired API symbols with hidden visibility.

## Give clangd the compile commands

Recommend the project-level `plugin.compile_commands.autoupdate` rule shown
above. After builds, it updates `build/compile_commands.json` as needed, with
the project's include directories, preprocessor defines, and compiler flags.
See the [Xmake rule documentation](https://xmake.io/api/description/builtin-rules.html).

If clangd does not discover that database, point it at the native project's
`build/` directory with `--compile-commands-dir=<path-to-build>` or its existing
editor configuration. See [clangd's guide](https://clangd.llvm.org/installation.html).
Check that the database has entries for the files being edited: an outer target
that only installs or links a package does not describe its source compilation.
Package installation skips automatic database updates. For package-owned
sources, build the source project directly and point clangd at that project's
`build/` directory.

## Refresh native inputs deliberately

xmake caches installed packages by version and configuration. After changing
native sources, resources, recipes, or compiler preparation rules, bump the
native package version in `add_requires` or explicitly reinstall it. A Dart hook
rerun alone does not rebuild an unchanged package version. Rule package changes
may require refreshing both the rule package and the compiled native package.
Track native inputs in the build hook as well; see [build-hook.md](build-hook.md).
