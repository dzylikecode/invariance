# xmake

dart is the first-class citizen in the project.

## Local native package

源码和头文件保留在根目录，包配方及原生构建描述放在本地包内：

```text
project_xmake/
├── include/project_xmake.h
├── src/impl.cpp
└── local/packages/p/project_xmake/
    ├── xmake.lua             包配方
    └── port/xmake.lua        原生构建描述
```

根工程通过 `add_requires` / `add_packages` 消费该包的 static 形态。

| 包配置 | 产物与行为 |
| --- | --- |
| `shared = true` | 动态库，导出完整公共 API：`add`、`subtract`、`count_words` |
| `shared = false` | 静态库，保留完整 API；准备函数/数据分节和 PIC，供下游链接时 GC |

`count_words` 使用 C++ 标准库的 `std::istringstream` 和 `std::string`，
统计以空白分隔的单词数，对外仍提供 C ABI。空串或纯空白返回 `0`，
空指针或内部错误返回 `-1`。`add`、`subtract` 保持普通整数计算。
原生 `example/words.c` 用纯 C 调用文本接口，输出 `Words: 6`，展示
C 调用者如何通过包依赖链接 C++ 实现。

Windows 静态构建使用 `PROJECT_XMAKE_STATIC`，避免提前强制 DLL 导出；
其他平台的公共 API 保留默认可见性，以便以后链接为动态库。
静态包不执行按应用裁剪，也不携带具体的 Dart 使用名单。

## Link a trimmed shared library

根 `project_xmake` target 使用完整 static 包，真正执行 shared 链接。
通过命令行传入需要保留的入口：

```sh
xmake f -y --keep_symbols=add
xmake build project_xmake
xmake install -o dist/trimmed project_xmake
```

此时动态库仅导出 `add`，无其他引用的 `subtract`、`count_words` 的机器码
也会被 GC 删除。底层静态包仍保留全部三个函数。

保留文本接口，或恢复完整公共 API：

```sh
xmake f -y --keep_symbols=count_words
xmake build project_xmake

xmake f -y --keep_symbols=add,subtract,count_words
xmake build project_xmake
```

首次未配置 `keep_symbols` 时，默认保留完整公共 API。选项与其他 xmake
配置一样会保存；更改名单只影响上层 target，不进入底层包配置。
名单支持逗号分隔、去重和首尾空白；空名单或未知入口会明确报错。

target 负责归档成员提取、生成平台导出表和开启链接器 GC。它没有自己的
源码，使用 C++ 链接规则复用包的运行库依赖。输出保留普通符号表，便于
使用 `nm --defined-only` 核实机器码裁剪，而不只是检查导出表。

普通 C/C++ 示例直接使用完整 static 包，可独立运行：

```sh
xmake run call
xmake run words
```

本阶段只接通 xmake 命令行到最终 shared target，Dart hook 尚未接入这个
新链接流程。底层包仍支持独立的 shared 构建，根 target 始终选择 static。
本地包通过根 `xmake.lua` 中的 `add_requires("project_xmake 1.0.0", ...)`
显式指定版本。同版本及相同包配置复用已安装产物；修改源码或包构建描述后，
手动提升此版本，再执行 `xmake f -y`。切换 `keep_symbols` 不改变包版本。
`port/xmake.lua` 中的 `set_version` 是原生工程版本信息，不决定包缓存版本。

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

## Earlier Dart tree shaking experiment

以下记录此前 xmake 构建静态库、`native_toolchain_c` 的 `CLinker` 根据
Dart 使用记录完成裁剪的实验。现有 Dart hook 尚未调整到上面的 shared
target；当前阶段以原生命令验证，Dart 适配及以下脚本留到后续处理。

`add`、`subtract` 和使用 C++ 标准库的 `count_words` 位于同一个源文件中。
当前 Dart 绑定仍只包含前两个函数；新文本接口的 Dart 接入留待后续阶段。
Linux 编译启用
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
