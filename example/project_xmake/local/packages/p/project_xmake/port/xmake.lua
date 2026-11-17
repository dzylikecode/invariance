-- Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
set_project("project_xmake")
set_version("1.0.0")
set_languages("c++11")
add_rules("mode.debug", "mode.release")

local kind = get_config("kind") or "static"
local sourceRoot = path.absolute("../../../../..", os.scriptdir())

add_repositories("dart-native " .. path.join(sourceRoot, "../.."))
add_requires("dart_native 1.0.0", {system = false})

target("project_xmake")
    set_kind(kind)
    add_packages("dart_native")
    add_rules("@dart_native/library", {kind = kind})
    add_files(path.join(sourceRoot, "src/impl.cpp"))
    add_includedirs(path.join(sourceRoot, "include"), {public = true})
    add_headerfiles(path.join(sourceRoot, "include/(project_xmake.h)"))

    if kind == "static" then
        -- Preserve every API, without forcing DLL exports into the archive.
        add_defines("PROJECT_XMAKE_STATIC", {public = true})
    else
        -- Shared packages expose the complete public C API.
        add_defines("PROJECT_XMAKE_BUILD")
    end
