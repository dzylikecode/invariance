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


