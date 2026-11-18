rule("library")
    on_config(function(target)
        local kind = target:extraconf("rules", "@dart_native/library", "kind")
        assert(kind == "static" or kind == "shared",
            "dart_native/library requires kind = 'static' or 'shared'")
        assert(target:kind() == kind, "dart_native/library kind must match the target kind")

        if kind == "static" then
            if target:is_plat("linux", "android", "bsd", "cross") then
                target:add("cxflags", "-fPIC", "-ffunction-sections", "-fdata-sections")
            elseif target:is_plat("windows") then
                target:add("cxflags", "/Gy", "/Gw", {tools = {"cl", "clang_cl"}})
                target:add("cxflags", "-ffunction-sections", "-fdata-sections",
                    {tools = {"gcc", "gxx", "clang", "clangxx", "zig_cc"}})
            elseif target:is_plat("mingw") then
                target:add("cxflags", "-ffunction-sections", "-fdata-sections")
            end
        elseif target:is_plat("macosx", "iphoneos") then
            -- Dart rewrites install names when bundling the shared library.
            target:add("shflags", "-Wl,-headerpad_max_install_names", {force = true})
        end
    end)
