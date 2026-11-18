# 用 C23 `#embed` 嵌入文本

通过 xmake 把 `resources/message.txt` 的 UTF-8 字节编译进程序，再从 C 或
Dart 输出。运行时无需读取或分发这个文本文件。原生代码由本地 xmake 包
编译，Dart link hook 把使用的符号交给 xmake，生成按需裁剪的动态库。

## 原理

`src/embed_text.c` 中的核心代码：

```c
static const unsigned char text[] = {
#embed "../resources/message.txt" suffix(, 0) if_empty(0)
};
```

`#embed` 会展开为逗号分隔的字节值，而不是字符串字面量。它不会自动追加
`\0`，所以这里用 `suffix(, 0)` 补上，空文件则用 `if_empty(0)` 保留一个终止字节。
对外返回的长度是 `sizeof(text) - 1`，不包含补上的字节。

C 示例使用 `fwrite`，Dart 通过生成的 FFI 绑定取得指针和长度后解码 UTF-8；
两者都不依赖 `strlen`，可以保留资源里原有的 `\0`。指针指向原生库拥有的只读
静态内存，调用方无需释放。

## 本地包和裁剪流程

源码、头文件和资源保留在原位置，包配方和构建描述放在本地仓库：

```text
embed_text/
├── include/embed_text.h
├── src/embed_text.c
├── resources/message.txt
├── xmake.lua
├── local/packages/e/embed_text/
│   ├── xmake.lua
│   └── port/xmake.lua
├── hook/
│   ├── build.dart
│   └── link.dart
└── lib/src/xmake.dart
```

根工程使用单个 `embed_text` target，并引用仓库中的 `dart_native` 规则包。

根工程和 `local/packages/e/embed_text/port/xmake.lua` 都显式设置
`configs = {local_source = true}`，从当前 checkout 读取规则源码。
`local_source` 是公共配方的自定义选项；默认模式会按 `dart_native 1.0.0`
下载固定 Git commit 的规则源码。修改本地规则后需要手动提升开发版本或重装
规则包；已发布版本到远程 commit 的映射保持不变。

| 配置 | 包输入与 target 行为 |
| --- | --- |
| `static`，无符号名单 | 构建完整静态包；phony target 安装包产物 |
| `shared`，无符号名单 | 构建并安装导出两个公共 API 的完整动态包 |
| `shared`，有符号名单 | 引用完整静态包；target 控制导出并执行 GC，生成裁剪后的动态库 |

静态包通过 `@dart_native/library` 准备分节和 PIC；最终链接使用
`@dart_native/link`。保留 `embed_text_data` 时，函数对 `text` 的引用会保留
嵌入资源。仅保留 `embed_text_size` 时，长度是编译期常量，未使用的
`embed_text_data` 和资源数据可以一起被删除。

Windows 静态包使用 `EMBED_TEXT_STATIC`，共享包使用 `EMBED_TEXT_BUILDING`；
最终导出集合由链接阶段决定。

## 编译器要求

需要 xmake，以及支持 C23 `#embed` 的 C 编译器。例如
[GCC 15 及以上](https://gcc.gnu.org/gcc-15/changes.html)或
[Clang 19 及以上](https://releases.llvm.org/19.1.0/tools/clang/docs/ReleaseNotes.html)。
`set_languages("c23")` 只选择语言模式，不会为旧编译器补上该特性。

[MSVC 的支持表目前仍将 `#embed` 标为不支持](https://learn.microsoft.com/en-us/cpp/overview/visual-cpp-language-conformance)。
在 macOS 或 Windows 上需要自行选择支持该特性的工具链，不能假定默认的
Apple Clang 或 MSVC 可以编译本例。

## 运行原生示例

在本目录构建完整静态包并运行 C 示例：

```sh
xmake f -c -y --kind=static
xmake build embed_text
xmake run embed_text_demo
```

安装完整动态包：

```sh
xmake f -c -y --kind=shared
xmake build embed_text
xmake install -o dist/shared embed_text
```

通过命令行只保留长度入口：

```sh
xmake f -c -y --kind=shared --keep_symbols='{"embed_text_size"}'
xmake build embed_text
```

`keep_symbols` 是 Lua 字符串列表，和 Dart 传入 xmake 的格式一致。

## Dart hooks

`hook/build.dart` 和 `hook/link.dart` 共用 `lib/src/xmake.dart` 的
`XmakeLibrary` 配置，采用 `linkHook: .auto`。未启用 linking 时，build hook
直接提供完整动态库；启用时先提供静态包，再由 link hook 根据
`recordUseMapping` 传递实际使用的原生符号。没有使用原生 API 时，原生库
不进入 bundle。

```sh
dart pub get
dart run example/main.dart

dart build cli --target=example/main.dart --output=build/cli/main
dart build cli --target=example/size.dart --output=build/cli/size
dart build cli --target=example/unused.dart --output=build/cli/unused
```

`main.dart` 读取并输出完整文本，使用两个原生入口；`size.dart` 只使用长度
入口；`unused.dart` 不使用原生 API。构建会自动调用 xmake，不需要手动
指定动态库路径。

生成的 FFI 绑定已包含在示例里。修改 `include/embed_text.h` 后重新生成：

```sh
dart run tool/ffigen.dart
```

测试集中在仓库根目录。在满足编译器要求的环境中，从仓库根目录运行：

```sh
dart test test/embed_text --concurrency=1
```

`test/embed_text/feature_test.dart` 验证接口功能，
`test/embed_text/link_test.dart` 验证未使用时省略原生库，以及只使用长度入口
时裁剪未使用函数和资源。它们通过 `test/helpers.dart` 共用临时工程准备流程。
[GitHub Actions](../../.github/workflows/project_xmake.yml) 仅在 Linux 上运行
本例测试，使用 Ubuntu 26.04 预装的 GCC 15。

## 修改源码和资源

本地原生包当前声明为 `embed_text 1.0.0`，xmake 会按包版本和配置复用安装
缓存。修改 `src/`、`include/`、`resources/` 或包的构建描述后，应升级
根工程 `add_requires` 声明的原生包版本。`port/xmake.lua` 的 `set_version`
是原生工程版本信息，不决定包缓存版本。

Dart hook 登记这些输入的依赖变化，但 hook 重新运行本身不会清除 xmake
同版本的包缓存。已编译的程序保留构建时嵌入的资源内容。

本地仓库的锁文件可能包含 checkout 的绝对路径，本例不提交这类路径锁；
依赖版本由 `add_requires` 显式指定。
