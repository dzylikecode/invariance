set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

-- kind: static, shared, headeronly
local kind = get_config("kind") or "static"

target("project_xmake")
  set_kind(kind)
  add_includedirs("include", {public = true}) -- visible to other targets
  add_headerfiles("include/*.h") -- export for installations
  add_files("src/*.cpp")

---------------------------------------------------------
--- Examples
---------------------------------------------------------
for _, file in ipairs(os.files("example/*.cpp")) do
    local name = path.basename(file)
    target(name)
      set_kind("binary")
      add_files(file)
      add_deps("project_xmake")
end
