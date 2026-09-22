set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

set_languages("c++17")

target("ffigen_metadata")
  set_kind("object")
  add_files("tool/py_3_8_20.cpp")
  add_includedirs("dist/3.8.20/include")

---------------------------------------------------------
--- Examples
---------------------------------------------------------
for _, file in ipairs(os.files("example/*.cpp")) do
    local name = path.basename(file)
    target(name)
      set_kind("binary")
      add_files(file)
      add_includedirs("dist/3.8.20/include", {public = true})
end
