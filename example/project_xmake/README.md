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

根工程通过 `add_requires` / `add_packages` 消费该包，build 和 link 共用
`project_xmake` target，包形态同时取决于 `--kind` 和符号列表：

| 阶段 | `kind` | `keep_symbols` | 原生包 | target 行为 |
| --- | --- | --- | --- | --- |
| 启用 linking 的 build | `static` | 无 | 静态包 | phony，安装完整归档 |
| 直接打包的 build | `shared` | 无 | 动态包 | phony，安装完整动态库 |
| link | `shared` | 有 | 静态包 | shared，链接并裁剪最终动态库 |

包配置使用 `shared = kind == "shared" and not keepSymbols`，保证最终裁剪
仍以静态包作为输入。

通用构建配置来自 `dart_native 1.0.0` 规则包。包索引位于仓库根目录的
`packages/d/dart_native/xmake.lua`，规则源码统一放在
`packages/native_toolchain_xmake/xmake/rules/`。根工程和包内的
`port/xmake.lua` 都通过本地仓库路径使用它：

| 规则 | 作用 |
| --- | --- |
| `@dart_native/library` | 按 `kind` 配置可裁剪的 static 编译选项或 shared 平台选项 |
| `@dart_native/install` | 安装指定包的完整目录树 |
| `@dart_native/link` | 按 `symbols` 链接、控制导出并裁剪 shared |

`set_kind` 和 `add_packages` 仍由 target 声明。`PROJECT_XMAKE_STATIC`、
`PROJECT_XMAKE_BUILD` 宏仍由本项目管理。
规则包使用当前 checkout 的源码；修改规则后手动提升规则包配方和
`add_requires` 中的版本，或强制重装同版本包。
修改 `library` 编译选项后，还需要提升或强制重装 `project_xmake` 原生包；
已经编译好的静态库、动态库不会自动采用新选项。

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
xmake f -y --kind=shared --keep_symbols='{"add"}'
xmake build project_xmake
xmake install -o dist/trimmed project_xmake
```

此时动态库仅导出 `add`，无其他引用的 `subtract`、`count_words` 的机器码
也会被 GC 删除。底层静态包仍保留全部三个函数。

保留文本接口，或恢复完整公共 API：

```sh
xmake f -y --kind=shared --keep_symbols='{"count_words"}'
xmake build project_xmake

xmake f -y --kind=shared --keep_symbols='{"add","subtract","count_words"}'
xmake build project_xmake
```

`keep_symbols` 没有默认名单；同一 target 仅在 shared 模式且传入该选项时
执行真实动态链接，否则为 phony target，安装完整包。选项与其他 xmake 配置一样会保存；
更改名单只影响上层 target，不进入底层包配置。
参数采用 Lua table literal 字符串，`@dart_native/link` 使用
`string.deserialize` 还原 table。Dart hook 通过 binding mapping 得到原生
符号名称。

target 负责归档成员提取、生成平台导出表和开启链接器 GC。它没有自己的
源码，使用 C++ 链接规则复用包的运行库依赖。输出保留普通符号表，便于
使用 `nm --defined-only` 核实机器码裁剪，而不只是检查导出表。

普通 C/C++ 示例直接使用完整 static 包，可独立运行：

```sh
xmake run call
xmake run words
```

`native_toolchain_xmake` 已接通这个流程：两个 hook 的 `XmakeLibrary` 都使用
`target: 'project_xmake'`。启用 linking 时，build hook 以 `--kind=static`
且不传名单，安装完整静态库。link hook 将 `symbolsToKeep` 序列化为 Lua
table literal 字符串，使用 `--kind=shared` 和 `--keep_symbols`，让同一
target 链接裁剪后的动态库。未启用 linking 时，build hook 以
`--kind=shared` 且不传名单，安装完整动态包。
本地包通过根 `xmake.lua` 中的 `add_requires("project_xmake 1.0.0", ...)`
显式指定版本。同版本及相同包配置复用已安装产物；修改源码或包构建描述后，
手动提升此版本，再执行 `xmake f -y`。切换 `keep_symbols` 不改变包版本。
`port/xmake.lua` 中的 `set_version` 是原生工程版本信息，不决定包缓存版本。
本示例只使用本地仓库，因此关闭 `package.requires_lock`，也不提交
`xmake-requires.lock`；该锁文件会记录当前 checkout 的绝对路径，无法在
其他机器或临时测试目录中复用。

## Tests

测试集中在仓库根目录，从仓库根目录运行：

```sh
dart test test/project_xmake --concurrency=1
```

- `test/project_xmake/feature_test.dart` 验证接口功能。
- `test/project_xmake/link_test.dart` 在独立临时 workspace 中执行 `dart build cli`，验证
  `unused` 不打包原生库，`call` 输出 `8` 且仅保留 `add` 接口。
  Linux 还通过 `nm` 检查未使用函数的代码已被裁剪。

临时工程使用当前 `native_toolchain_xmake` 源码，不复制已有构建产物。
测试通过根目录的 `test/helpers.dart` 共用临时工程准备流程。
测试失败时显示构建日志；设置 `KEEP_TEMPORARY_DIRECTORIES=1` 可保留临时
工程以便排查。只运行构建测试时，执行
`dart test test/project_xmake/link_test.dart`。

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
`symbolsToKeep` 必须传入列表；没有使用记录时，Dart hook 显式使用
`recordUseMapping.values` 保留全部绑定接口。空名单跳过整个原生库。每次
link 的动态库保存在该 hook 的输出目录中。

`add`、`subtract` 和使用 C++ 标准库的 `count_words` 位于同一个源文件中。
当前 Dart 绑定仍只包含前两个函数；新文本接口的 Dart 接入留待后续阶段。
Linux 编译启用
`-ffunction-sections -fdata-sections`，使链接器能够删除单个函数。
仅限制导出符号会隐藏 `subtract`，不一定删除它的代码。

从仓库根目录运行：

```sh
dart test test/project_xmake/link_test.dart
```

构建测试验证：

| 场景 | 预期结果 |
| --- | --- |
| 只调用 `add` | 返回 `8`，可查找 `add`，无法查找 `subtract`、`count_words` |
| 只使用 Dart 常量 | 整个原生库不进入 bundle |

Linux 额外使用 GNU `nm` 检查精确导出名单和普通符号表，确认未使用
函数的代码已被裁剪。临时工程、失败日志和清理方式见 Tests 一节。
