set_project("embed_text")
set_version("1.0.0")
set_languages("c23")
-- Local repository locks contain checkout-specific absolute paths.
set_policy("package.requires_lock", false)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

option("keep_symbols")
    set_showmenu(true)
    set_description("Lua table of native symbols supplied by Dart")
option_end()

local kind = get_config("kind") or "static"
local symbols = get_config("keep_symbols")

add_repositories("local-repo local", {rootdir = os.scriptdir()})
add_repositories("dart-native ../..", {rootdir = os.scriptdir()})
add_requires("dart_native 1.0.0", {system = false, configs = {local_source = true}})
-- Bump this version when native sources, resources, or the build recipe change.
add_requires("embed_text 1.0.0", {
    system = false,
    configs = {shared = kind == "shared" and not symbols, pic = true}
})

target("embed_text")
    add_packages("embed_text", "dart_native")
    if kind == "shared" and symbols then
        set_kind("shared")
        add_rules("@dart_native/link", {symbols = symbols})
        -- Keep the symbol table so tests can distinguish GC from hidden exports.
        set_strip("none")
    else
        set_kind("phony")
        add_rules("@dart_native/install", {package = "embed_text"})
    end
target_end()

target("embed_text_demo")
    set_kind("binary")
    add_files("example/main.c")
    add_packages("embed_text")
