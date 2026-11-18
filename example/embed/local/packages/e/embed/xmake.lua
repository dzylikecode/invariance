package("embed")
    set_description("C23 embedded text with shared and GC-ready static libraries")
    set_license("MIT")
    set_sourcedir(path.join(os.scriptdir(), "port"))

    on_load(function(package)
        if not package:config("shared") then
            package:add("defines", "EMBED_STATIC")
        end
    end)

    on_install(function(package)
        import("package.tools.xmake").install(package)
    end)

    on_test(function(package)
        assert(package:has_cfuncs("file1_data", {includes = "embed.h"}))
        assert(package:has_cfuncs("file1_size", {includes = "embed.h"}))
    end)
