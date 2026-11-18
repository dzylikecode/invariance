package("dart_native")
    set_kind("binary")
    set_description("Xmake rules for building and linking Dart native libraries")
    set_license("MIT")

    -- Keep released version-to-commit mappings immutable; bump the version for new sources.
    add_versions("1.0.0", "c241d2c9efcf6fbd1ab5d47614cb8614fec14fc2")
    add_configs("local_source", {
        description = "Use rules from the current repository checkout",
        default = false,
        type = "boolean"
    })

    on_source(function(package)
        if package:config("local_source") then
            package:set("sourcedir", path.absolute("../../..", package:scriptdir()))
        else
            package:add("urls", "https://github.com/dzylikecode/invariance.git")
        end
    end)

    on_install(function(package)
        os.cp(path.join("packages", "native_toolchain_xmake", "xmake", "rules"), package:installdir())
    end)

    on_test(function(package)
        for _, name in ipairs({"library.lua", "install.lua", "link.lua"}) do
            assert(os.isfile(package:installdir(path.join("rules", name))),
                "dart_native is missing rule file: " .. name)
        end
    end)
