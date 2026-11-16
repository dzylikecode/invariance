set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

-- kind: static, shared, headeronly
local kind = get_config("kind") or "static"

target("project_xmake")
  set_kind(kind)
  if is_plat("linux", "android") then
    -- A whitelist alone hides symbols; separate sections allow code removal.
    add_cxflags("-fPIC", "-ffunction-sections", "-fdata-sections")
  elseif is_plat("windows") then
    add_cxflags("/Gy", "/Gw", {tools = {"cl", "clang_cl"}})
    add_cxflags("-ffunction-sections", "-fdata-sections",
      {tools = {"gcc", "gxx", "clang", "clangxx", "zig_cc"}})
  end
  if is_plat("linux") then
    add_defines("PROJECT_XMAKE_CPP_RUNTIME_PROBE")
  end
  if kind == "static" then
    -- The final link selects exports; dllexport would retain unused functions.
    add_defines("PROJECT_XMAKE_STATIC", {public = true})
  elseif kind == "shared" then
    add_defines("PROJECT_XMAKE_BUILD")
  end
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
