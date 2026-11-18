package("embed")
    set_description("C23 embedded resources with shared and GC-ready static libraries")
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
        for _, name in ipairs({
            "asset_file1_txt_data", "asset_file1_txt_size",
            "asset_fold1_file1_txt_data", "asset_fold1_file1_txt_size"
        }) do
            assert(package:has_cfuncs(name, {includes = "embed.h"}))
        end
    end)
