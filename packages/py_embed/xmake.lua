set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

set_languages("c++17")

---------------------------------------------------------
--- Examples
---------------------------------------------------------
for _, file in ipairs(os.files("tool/py_*.cpp")) do
    local name = path.basename(file)
    local major, minor, patch = name:match("^py_(%d+)_(%d+)_(%d+)$")
    local version = table.concat({major, minor, patch}, ".")

    target(name)
      set_kind("shared")
      add_files(file)
      add_includedirs(path.join("dist", version, "include"), {public = true})
end

target("shared")
  set_kind("shared")
  add_files("tool/shared.cpp")
  add_includedirs(path.join("dist", "3.8.20", "include"), {public = true})
