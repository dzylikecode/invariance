-- Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
package("dart_native")
    set_kind("binary")
    set_description("Xmake rules for building and linking Dart native libraries")
    set_license("MIT")

    -- Bump this version when the embedded rules change; no archive is downloaded.
    add_versions("1.0.0", "")
    set_sourcedir(path.join(os.scriptdir(), "../../native_toolchain_xmake/xmake"))

    on_install(function(package)
        os.cp("rules", package:installdir())
    end)

    on_test(function(package)
        for _, name in ipairs({"library.lua", "install.lua", "link.lua"}) do
            assert(os.isfile(package:installdir(path.join("rules", name))),
                "dart_native is missing rule file: " .. name)
        end
    end)
