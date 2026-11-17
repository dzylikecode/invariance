set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"})

local publicSymbols = {"add", "subtract", "count_words"}

local function parseKeepSymbols(value)
  if type(value) ~= "string" then
    return nil, "keep_symbols must be a comma-separated symbol list"
  end
  local symbols = {}
  for _, symbol in ipairs(value:split(",")) do
    symbol = symbol:trim()
    if not table.contains(publicSymbols, symbol) then
      return nil, "Unknown public symbol in keep_symbols: " .. symbol
    end
    if not table.contains(symbols, symbol) then
      table.insert(symbols, symbol)
    end
  end
  if #symbols == 0 then
    return nil, "keep_symbols must name at least one public symbol"
  end
  table.sort(symbols)
  return symbols
end

option("keep_symbols")
  set_default(table.concat(publicSymbols, ","))
  set_showmenu(true)
  set_description("Comma-separated public C symbols to keep in the shared library")
option_end()

add_repositories("local-repo local")
-- Bump this version when the local package sources or build recipe change.
add_requires("project_xmake 1.0.0", {
  system = false,
  configs = {shared = get_config("kind") == "shared", pic = true}
})

target("project_xmake_build")
  set_kind("phony")
  add_packages("project_xmake")

  on_config(function(target)
    local pkgdir = target:pkg("project_xmake"):installdir()

    target:add("installfiles", path.join(pkgdir, "**"), {
      rootdir = pkgdir
    })
  end)

-- Link the complete static package into a shared library for this symbol set.
target("project_xmake")
  set_kind("shared")
  add_rules("c++", "utils.symbols.export_list")
  add_packages("project_xmake")
  -- Keep the regular symbol table so code removal can be inspected with nm.
  set_strip("none")

  on_load(function(target)
    local symbols = assert(parseKeepSymbols(get_config("keep_symbols")))
    target:extraconf_set("rules", "utils.symbols.export_list", "symbols", symbols)
  end)

  on_config(function(target)
    local symbols = target:extraconf("rules", "utils.symbols.export_list", "symbols")
    local linkerName = target:linker():name()
    assert(table.contains({"gcc", "gxx", "clang", "clangxx", "link"}, linkerName),
      "Symbol export control is not supported for linker: " .. linkerName)
    if target:has_tool("ld", "link") then
      -- The generated .def exports also pull the required archive members.
      target:add("shflags", "/OPT:REF", {force = true})
    elseif target:is_plat("windows") and target:has_tool("ld", "clangxx") then
      target:add("shflags", "-Wl,/OPT:REF", {force = true})
    elseif target:is_plat("macosx", "iphoneos") then
      target:add("shflags", "-Wl,-dead_strip", {force = true})
      for _, symbol in ipairs(symbols) do
        target:add("shflags", "-Wl,-u,_" .. symbol, {force = true})
      end
    else
      target:add("shflags", "-Wl,--gc-sections", "-Wl,--no-undefined", {force = true})
      for _, symbol in ipairs(symbols) do
        local prefix = target:is_plat("mingw") and target:is_arch("i386", "x86") and "_" or ""
        target:add("shflags", "-Wl,-u," .. prefix .. symbol, {force = true})
      end
    end
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
