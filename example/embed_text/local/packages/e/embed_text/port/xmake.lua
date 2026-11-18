set_project("embed_text")
set_version("1.0.0")
set_languages("c23")
add_rules("mode.debug", "mode.release")

local kind = get_config("kind") or "static"
local sourceRoot = path.absolute("../../../../..", os.scriptdir())

add_repositories("dart-native " .. path.join(sourceRoot, "../.."))
add_requires("dart_native 1.0.0", {system = false})

target("embed_text")
    set_kind(kind)
    add_packages("dart_native")
    add_rules("@dart_native/library", {kind = kind})
    add_files(path.join(sourceRoot, "src/embed_text.c"))
    add_includedirs(path.join(sourceRoot, "include"), {public = true})
    add_headerfiles(path.join(sourceRoot, "include/(embed_text.h)"))

    if kind == "static" then
        add_defines("EMBED_TEXT_STATIC", {public = true})
    else
        add_defines("EMBED_TEXT_BUILDING")
    end
