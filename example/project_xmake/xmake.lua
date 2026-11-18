-- Local repository locks contain checkout-specific absolute paths.
set_policy("package.requires_lock", false)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

option("keep_symbols", {
    description = "Lua table of native symbols supplied by Dart"
})

local outputKind = get_config("kind") or "static"
local symbols = get_config("keep_symbols")
local linking = outputKind == "shared" and symbols
local packageKind = linking and "static" or outputKind

add_repositories("local-repo local", {rootdir = os.scriptdir()})
add_repositories("dart-native ../..", {rootdir = os.scriptdir()})
add_requires("dart_native 1.0.0", {system = false, configs = {local_source = true}})
-- Bump this version when the local package sources or build recipe change.
add_requires("project_xmake 1.0.0", {
  system = false,
  configs = {shared = packageKind == "shared"}
})

target("project_xmake")
  add_packages("project_xmake", "dart_native")
  if linking then
    set_kind("shared")
    add_rules("@dart_native/link", {symbols = symbols})
    -- Keep the regular symbol table so code removal can be inspected with nm.
    set_strip("none")
  else
    set_kind("phony")
    add_rules("@dart_native/install", {package = "project_xmake"})
  end
target_end()

---------------------------------------------------------
--- Examples
---------------------------------------------------------
for _, file in ipairs(table.join(os.files("example/*.c"), os.files("example/*.cpp"))) do
    local name = path.basename(file)
    target(name)
      set_kind("binary")
      add_files(file)
      add_packages("project_xmake")
end
