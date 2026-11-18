package("project_xmake")
    set_description("Local C API example with shared and GC-ready static libraries")
    set_license("MIT")
    set_sourcedir(path.join(os.scriptdir(), "port"))

    on_load(function(package)
        if not package:config("shared") then
            package:add("defines", "PROJECT_XMAKE_STATIC")
            -- C consumers need the runtime used by the C++ implementation.
            if package:is_plat("linux", "mingw") then
                package:add("syslinks", "stdc++")
            elseif package:is_plat("macosx", "iphoneos", "bsd") then
                package:add("syslinks", "c++")
            end
        end
    end)

    on_install(function(package)
        import("package.tools.xmake").install(package)
    end)

    on_test(function(package)
        assert(package:has_cxxfuncs("add", {includes = "project_xmake.h"}))
        assert(package:has_cxxfuncs("subtract", {includes = "project_xmake.h"}))
        assert(package:has_cxxfuncs("count_words", {includes = "project_xmake.h"}))
    end)
