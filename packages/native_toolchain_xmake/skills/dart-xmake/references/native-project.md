# Prepare the native project

Extend the existing native compilation target with the Dart integration below.
Use a reusable native package when other xmake projects consume the library or
the Dart link hook needs an archive-to-shared link flow.

For ordinary source projects, prefer a complete native project under
`backend/<language>/`, such as `backend/cpp/`. Keep its build script, public
headers, implementation, and native examples together so it can be built without
the Dart hooks. Use the language directory that fits the implementation; keep
specialized resource and packaging layouts where they serve the project.

## Attach the published library rule

The `dart_native` rule package provides `library`, `install`, and `link` rules.
For normal use, register the public repository and require its version:

```lua
add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})
```

The version selects a fixed Git source commit. Use the same rule package version
in the consuming project and the native package's source project. Add this wiring
to the existing compilation target, retaining its sources and other settings:

```lua
-- Project scope; use the same kind for the target and rule.
local kind = get_config("kind") or "shared"

-- Inside the existing compilation target:
set_kind(kind)
add_packages("dart_native")
add_rules("@dart_native/library", {kind = kind})
if kind == "static" then
    add_defines("EXAMPLE_NATIVE_STATIC", {public = true})
else
    add_defines("EXAMPLE_NATIVE_BUILD")
end
```

The rule requires `static` or `shared` and asserts that its `kind` matches the
target. For static inputs it enables function/data sections on supported
platforms and PIC on Linux, Android, BSD, and `cross`, preparing archives for
later shared linking and GC. On Apple shared builds it reserves install-name
header space for Dart bundling. Keep API macro ownership in the project.

## Define a C ABI

For package-owned headers, prefer `#pragma once`, separate C linkage from symbol
visibility, and compose both in the API macro on each public function. Preserve
an existing header convention when adapting a library. Keep the manually
indented preprocessor region between clang-format off/on markers.

`backend/cpp/include/example_native.h`:

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

The linkage macro avoids an outer `extern "C"` block. Define the build macro
only while building the shared library, and publish the static macro to static
consumers. Adapt the prefix and macro names to the project.

## Connect the native source project

Apply the library-rule wiring above in `backend/cpp/xmake.lua`. Resolve the
compilation inputs relative to that native project:

```lua
-- Inside the compilation target:
add_files("src/**.cpp")
add_includedirs("include", {public = true})
add_headerfiles("include/(**.h)")
```

Native examples in that project can use `add_deps` to consume the library target.
For direct shared bundling, the Dart package's root `xmake.lua` can be a thin
entrypoint containing `includes("backend/cpp")`.

When building from `backend/cpp/`, pass `-P .` to xmake commands to explicitly
select the inner project when an outer `xmake.lua` is also present.

For package-based integration, put the recipe in
`local/packages/e/example_native/xmake.lua`. Point it at the complete native
source project, install the library target, and publish the static macro in
package metadata:

```lua
package("example_native")
    set_sourcedir(path.join(os.scriptdir(), "../../../../backend/cpp"))

    on_load(function(package)
        if not package:config("shared") then
            package:add("defines", "EXAMPLE_NATIVE_STATIC")
        end
    end)

    on_install(function(package)
        import("package.tools.xmake").install(package, {}, {
            target = "example_native"
        })
    end)
```

Selecting the target applies to both building and installation, so unrelated
native examples remain available for standalone development without entering
the Dart package build. This layout does not need a separate `port/` script.

If the implementation is C++, publish its required runtime/system link
dependencies too, so C consumers can link it. In the invariance repository,
`example/project_xmake/local/packages/p/project_xmake/` shows this case.

Replace the Dart package's root compilation target with the package install/link
selector in [tree-shaking.md](tree-shaking.md). The source target still owns
compilation; the root target installs its finished library or links its archive.
Native functions must remain available for that final export selection. Avoid
forced DLL exports or `used`/`retain` attributes in static inputs, and do not
compile desired API symbols with hidden visibility.

## Generate compile commands from the compilation project

Recommend this project-level rule in the project that owns native compilation:

```lua
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})
```

Check that the database has entries for the files being edited: an outer target
that is phony or only installs/links a package does not describe its source
compilation. Package installation skips automatic database updates. For
package-owned sources, build `backend/cpp/` directly and point clangd at that
project's `build/` directory using its existing editor configuration. Standalone
use also needs the rule repository to resolve independently; repository-local
rule paths are development configuration rather than part of the library API.

## Refresh native inputs deliberately

xmake caches installed packages by version and configuration. Keep native
package version bumps manual: after changing native sources, resources, recipes,
or compiler preparation rules, bump the version in `add_requires` in the root
`xmake.lua` or explicitly reinstall the package. A Dart hook rerun alone does not
rebuild an unchanged package version. Rule package changes may require
refreshing both the rule package and the compiled native package.

The Dart build hook tracks only the root `xmake.lua` for native build changes.
Native source edits alone do not rerun it. Update the package version or
configuration in that root file to trigger package-based builds; direct builds
also use the root entrypoint as their explicit invalidation point. See
[build-hook.md](build-hook.md).
