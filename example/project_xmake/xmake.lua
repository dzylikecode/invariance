set_policy("package.requires_lock", true)
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
add_requires("dart_native 1.0.0", {system = false})
-- Bump this version when the local package sources or build recipe change.
add_requires("project_xmake 1.0.0", {
  system = false,
  configs = {shared = kind == "shared" and not symbols, pic = true}
})

target("project_xmake")
  add_packages("project_xmake", "dart_native")
  if kind == "shared" and symbols then
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
