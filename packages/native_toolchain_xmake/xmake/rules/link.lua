rule("link")
    add_deps("c++", "utils.symbols.export_list")

    before_config(function(target)
        assert(target:is_shared(), "@dart_native/link requires a shared target")
        local symbols = target:extraconf("rules", "@dart_native/link", "symbols")
        if type(symbols) == "string" then
            symbols = assert(symbols:deserialize())
        end
        assert(type(symbols) == "table" and #symbols > 0,
            "@dart_native/link requires a non-empty symbols list")
        local normalized = {}
        for _, symbol in ipairs(symbols) do
            assert(type(symbol) == "string" and #symbol:trim() > 0,
                "@dart_native/link symbols must be non-empty strings")
            table.insert(normalized, symbol:trim())
        end
        normalized = table.unique(normalized)
        table.sort(normalized)

        -- All before_config callbacks run before export_list's on_config.
        target:extraconf_set("rules", "utils.symbols.export_list", "symbols", normalized)
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
            target:add("shflags", "-Wl,-dead_strip", "-Wl,-headerpad_max_install_names", {force = true})
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
