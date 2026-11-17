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

根工程通过 `add_requires` / `add_packages` 消费该包，包形态跟随 `--kind`。

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
xmake f -y --kind=static --keep_symbols=add
xmake build project_xmake
xmake install -o dist/trimmed project_xmake
```

此时动态库仅导出 `add`，无其他引用的 `subtract`、`count_words` 的机器码
也会被 GC 删除。底层静态包仍保留全部三个函数。

保留文本接口，或恢复完整公共 API：

```sh
xmake f -y --kind=static --keep_symbols=count_words
xmake build project_xmake

xmake f -y --kind=static --keep_symbols=add,subtract,count_words
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

`native_toolchain_xmake` 已接通这个流程：build hook 使用
`project_xmake_build` 导出完整静态库，link hook 将 `symbolsToKeep` 转成
`--keep_symbols`，再构建 `project_xmake` shared target。未启用 linking
时，build hook 仍使用 `project_xmake_build`，通过 `--kind=shared` 安装完整
动态包。包的 `configs.shared` 跟随 `kind`；link hook 使用 `--kind=static`
保留静态包输入，再由显式声明为 shared 的 `project_xmake` target 链接输出。
本地包通过根 `xmake.lua` 中的 `add_requires("project_xmake 1.0.0", ...)`
显式指定版本。同版本及相同包配置复用已安装产物；修改源码或包构建描述后，
手动提升此版本，再执行 `xmake f -y`。切换 `keep_symbols` 不改变包版本。
`port/xmake.lua` 中的 `set_version` 是原生工程版本信息，不决定包缓存版本。

## Tests

在本目录运行 `dart test`：

- `test/feature_test.dart` 验证接口功能。
- `test/link_test.dart` 在独立临时 workspace 中执行 `dart build cli`，验证
  `unused` 不打包原生库，`call` 输出 `8` 且仅保留 `add` 接口。
  Linux 还通过 `nm` 检查未使用函数的代码已被裁剪。

临时工程使用当前 `native_toolchain_xmake` 源码，不复制已有构建产物。
测试失败时显示构建日志；设置 `KEEP_TEMPORARY_DIRECTORIES=1` 可保留临时
工程以便排查。只运行构建测试时，执行 `dart test test/link_test.dart`。

[GitHub Actions](../../.github/workflows/project_xmake.yml) 在 Linux、macOS、
Windows 上运行这套测试和工具链单元测试，支持相关 PR、主分支变更及手动触发。

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

## Dart tree shaking

Dart link hook 将使用记录映射为原生符号名单，通过
`XmakeLibrary.link(symbolsToKeep: ...)` 交给 xmake 完成最终链接和裁剪。
`null` 恢复 xmake 默认名单；空名单跳过整个原生库。每次 link 的动态库
保存在该 hook 的输出目录中。

`add`、`subtract` 和使用 C++ 标准库的 `count_words` 位于同一个源文件中。
当前 Dart 绑定仍只包含前两个函数；新文本接口的 Dart 接入留待后续阶段。
Linux 编译启用
`-ffunction-sections -fdata-sections`，使链接器能够删除单个函数。
仅限制导出符号会隐藏 `subtract`，不一定删除它的代码。

从本目录运行：

```sh
dart test test/link_test.dart
```

构建测试验证：

| 场景 | 预期结果 |
| --- | --- |
| 只调用 `add` | 返回 `8`，可查找 `add`，无法查找 `subtract`、`count_words` |
| 只使用 Dart 常量 | 整个原生库不进入 bundle |

Linux 额外使用 GNU `nm` 检查精确导出名单和普通符号表，确认未使用
函数的代码已被裁剪。临时工程、失败日志和清理方式见 Tests 一节。
