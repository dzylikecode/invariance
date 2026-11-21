set_project("project_xmake")
set_version("1.0.0")
set_languages("c++11")
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

local kind = get_config("kind") or "static"

add_repositories("dart-native " .. path.absolute("../../../..", os.scriptdir()))
add_requires("dart_native 1.0.0", {system = false, configs = {local_source = true}})

target("project_xmake")
    set_kind(kind)
    add_packages("dart_native")
    add_rules("@dart_native/library", {kind = kind})
    add_files("src/**.cpp")
    add_includedirs("include", {public = true})
    add_headerfiles("include/(**.h)")

    if kind == "static" then
        -- Preserve every API, without forcing DLL exports into the archive.
        add_defines("PROJECT_XMAKE_STATIC", {public = true})
    else
        -- Shared packages expose the complete public C API.
        add_defines("PROJECT_XMAKE_BUILD")
    end

-- These examples use the native target directly.
for _, file in ipairs(table.join(os.files("example/*.c"), os.files("example/*.cpp"))) do
    local name = path.basename(file)
    target(name)
        set_kind("binary")
        add_files(file)
        add_deps("project_xmake")
end
