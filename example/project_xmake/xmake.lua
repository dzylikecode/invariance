set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

local kind = get_config("kind") or "static"

add_repositories("local-repo local")
add_requires("project_xmake", {
  system = false,
  configs = {shared = kind == "shared", pic = true}
})

-- The package owns compilation. This target installs its finished library.
target("project_xmake")
  set_kind("phony")
  add_packages("project_xmake")
  on_install(function(target)
    local pkg = target:pkg("project_xmake")
    local directory = kind == "shared" and target:is_plat("windows", "mingw") and "bin" or "lib"
    local pattern
    if kind == "static" then
      pattern = target:is_plat("windows") and "lib/project_xmake.lib" or "lib/libproject_xmake.a"
    elseif target:is_plat("windows", "mingw") then
      pattern = "bin/*.dll"
    elseif target:is_plat("macosx", "iphoneos") then
      pattern = "lib/*.dylib"
    else
      pattern = "lib/*.so*"
    end
    local libraries = os.files(path.join(pkg:installdir(), pattern))
    assert(#libraries > 0, "project_xmake package contains no matching library: " .. pattern)
    os.mkdir(path.join(target:installdir(), directory))
    for _, library in ipairs(libraries) do
      os.vcp(library, path.join(target:installdir(), directory))
    end
    os.vcp(path.join(pkg:installdir(), "include"), target:installdir())
  end)

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
