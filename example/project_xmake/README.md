# xmake

dart is the first-class citizen in the project.

## cross-compile

```bash
dart build cli --target example/call.dart --target-os linux --target-arch x64
```

## notes

### add_headerfiles and add_includedirs

```lua
add_includedirs("include", {public = true})
```

有两个作用:

首先，编译 `foo` 自己时会有：

```bash
-I/path/to/foo/include
```

其次，因为有：

```lua
{public = true}
```

如果另一个 target：

```lua
target("app")
    add_deps("foo")
```

那么 `app` 也会自动获得这个 include path。

所以它可以直接：

```cpp
#include <foo/foo.h>
```

---

而：

```lua
add_headerfiles("include/(foo/*.h)")
```

这里的括号还有一个重要作用。

源目录：

```text
include/foo/foo.h
include/foo/types.h
```

安装之后会变成：

```text
include/
└── foo/
    ├── foo.h
    └── types.h
```

而不是：

```text
include/
└── include/
    └── foo/
        ├── foo.h
        └── types.h
```

也就是说：

```lua
add_headerfiles("include/(foo/*.h)")
```

括号表示安装时从括号里面这一层开始保留目录结构。

## 如何处理不同的结构体

## Native tree shaking experiment

这个示例沿用现有流程：xmake 构建静态库，`native_toolchain_c`
的 `CLinker` 根据 Dart 使用记录完成最终链接与裁剪。没有新增链接后端。

`add` 和 `subtract` 位于同一个 C++ 源文件中。Linux 上的 `add` 特意调用
`std::string`，让测试覆盖 C++ 运行库链接。Linux 编译启用
`-ffunction-sections -fdata-sections`，使链接器能够删除单个函数。
仅限制导出符号会隐藏 `subtract`，不一定删除它的代码。

从本目录运行：

```sh
dart run tool/verify_native_assets.dart
```

脚本在 Linux 本机验证：

| 场景 | 预期结果 |
| --- | --- |
| 只调用 `add` | 返回 `8`，仅导出 `add`，普通符号表中也不存在 `subtract` |
| 调用两个函数 | 两个函数都能运行并导出 |
| 只使用 Dart 常量 | 整个原生库不进入 bundle |
| 缺少使用记录 | 保守保留两个公开函数 |

静态输入仍包含两个函数；脚本同时检查输入归档与输出库，避免把
隐藏符号或删除调试信息误判成代码裁剪。需要 `xmake` 和 GNU `nm`。
验证产物写入忽略的 `.dart_tool/native_assets_check/`。

### ARM64 工具链实验

`xmake.lua` 为 Linux ARM64 显式选择 GNU 交叉工具链，与此目标下
`CLinker` 使用的 GNU C++ ABI 保持一致。需要安装
`aarch64-linux-gnu-gcc`、`g++` 和 binutils。这个选择只作用于示例，
没有修改 `native_toolchain_xmake` 的默认工具链策略。

```sh
dart build cli --target=example/call.dart \
  --target-os=linux --target-arch=arm64 \
  --output=.dart_tool/treeshake_arm64
```

构建出的原生库应只导出 `add`，且通过 `-z defs` 的符号解析检查。
交叉构建后仍需在 ARM64 或配置了目标系统库的 QEMU 中验证加载。
交叉构建 CLI 的启动器架构也应单独检查。
