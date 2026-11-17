-- Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
set_project("project_xmake")
set_version("1.0.0")
set_languages("c++11")
add_rules("mode.debug", "mode.release")

local kind = get_config("kind") or "static"
local sourceRoot = path.absolute("../../../../..", os.scriptdir())

target("project_xmake")
    set_kind(kind)
    add_files(path.join(sourceRoot, "src/impl.cpp"))
    add_includedirs(path.join(sourceRoot, "include"), {public = true})
    add_headerfiles(path.join(sourceRoot, "include/(project_xmake.h)"))

    if kind == "static" then
        -- Preserve every API, without forcing DLL exports into the archive.
        add_defines("PROJECT_XMAKE_STATIC", {public = true})
        if is_plat("linux", "android", "bsd", "cross") then
            add_cxflags("-fPIC", "-ffunction-sections", "-fdata-sections")
        elseif is_plat("windows") then
            add_cxflags("/Gy", "/Gw", {tools = {"cl", "clang_cl"}})
            add_cxflags("-ffunction-sections", "-fdata-sections",
                {tools = {"gcc", "gxx", "clang", "clangxx", "zig_cc"}})
        elseif is_plat("mingw") then
            add_cxflags("-ffunction-sections", "-fdata-sections")
        end
    else
        -- Shared packages expose the complete public C API.
        add_defines("PROJECT_XMAKE_BUILD")
        if is_plat("macosx", "iphoneos") then
            -- Dart rewrites install names when bundling the shared library.
            add_shflags("-Wl,-headerpad_max_install_names", {force = true})
        end
    end
