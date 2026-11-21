package("multi_lang")
    set_description("Local C API example with shared and GC-ready static libraries")
    set_license("MIT")
    set_sourcedir(path.join(os.scriptdir(), "../../../../backend/cpp"))

    on_load(function(package)
        if not package:config("shared") then
            -- 这个是使用包的时候定义头文件的宏，项目里面定义的是制作包里面使用的宏
            package:add("defines", "MULTI_LANG_STATIC")
            -- C consumers need the runtime used by the C++ implementation.
            if package:is_plat("linux", "mingw") then
                package:add("syslinks", "stdc++")
            elseif package:is_plat("macosx", "iphoneos", "bsd") then
                package:add("syslinks", "c++")
            end
        end
    end)

    on_install(function(package)
        import("package.tools.xmake").install(package, {}, {
        target = "multi_lang"
    })
    end)

    on_test(function(package)
        assert(package:has_cxxfuncs("greet", {includes = "multi_lang.h"}))
    end)
