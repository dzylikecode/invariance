# invariance

写出的代码据有不变性

## code environment

- vscode
- plugin: clangd

```lua

set_policy("package.requires_lock", true)
add_rules("mode.debug", "mode.release")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build/"}) -- used by clangd
```

## 跨平台指针

透明指针：https://github.com/itas109/CSerialPort/issues/106


## toolchain

- https://github.com/fzyzcjy/flutter_rust_bridge
- https://github.com/boltffi/boltffi
- https://github.com/rust-diplomat/diplomat
- https://github.com/cunarist/rinf
