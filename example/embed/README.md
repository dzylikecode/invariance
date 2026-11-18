# 用 C23 `#embed` 嵌入资源

通过 xmake 把 `assets/` 中的原始字节编译进程序，再从 C 或
Dart 访问。运行时无需读取或分发资源文件。原生代码由本地 xmake 包
编译，Dart link hook 把使用的符号交给 xmake，生成按需裁剪的动态库。

## 原理

`src/embed.c` 中的核心代码：

```c
static const uint8_t asset_file1_txt[] = {
#embed "../assets/file1.txt"
};

const uint8_t *asset_file1_txt_data(void) { return asset_file1_txt; }
size_t asset_file1_txt_size(void) { return sizeof(asset_file1_txt); }
```

`#embed` 会展开为逗号分隔的字节值，而不是字符串字面量。本例直接保存
文件字节，不追加终止字节。`asset_file1_txt_data()` 返回数组指针，
`asset_file1_txt_size()` 返回 `sizeof(asset_file1_txt)`，即文件的字节数。

C 示例使用 `fwrite`，Dart 通过生成的 FFI 绑定取得指针和长度，再复制为
`Uint8List`；两者都按显式长度读取，可以保留资源里原有的 `\0`。指针通过
`const uint8_t *` 暴露原生库拥有的静态内存，调用方无需释放。

## 资源映射

当前先手写映射，每个资源都有独立的 C 入口和 Dart 常量：

| 文件 | C 入口前缀 | Dart 入口 |
| --- | --- | --- |
| `assets/file1.txt` | `asset_file1_txt` | `Assets.file1Txt` |
| `assets/fold1/file1.txt` | `asset_fold1_file1_txt` | `Assets.fold1File1Txt` |

C 入口分别追加 `_data` 和 `_size`。Dart 常量保存各自读取函数的引用，
读取函数直接调用对应的两个 C 入口，使使用记录能识别保留的符号。
通过 `.bytes` 按需读取，不建立运行时的资源查找表：

```dart
import 'dart:convert';

import 'package:embed/embed.dart';

void main() {
  final bytes = Assets.file1Txt.bytes;
  print(utf8.decode(bytes));
  print(Assets.fold1File1Txt.bytes.length);
}
```

`.bytes` 每次返回 Dart 持有的副本，修改它不会改变原生资源。文本解码由
调用方决定，二进制资源可以直接使用字节。示例中的嵌套文件当前为空，读取
结果是空 `Uint8List`。

## 本地包和裁剪流程

源码、头文件和资源保留在原位置，包配方和构建描述放在本地仓库：

```text
embed/
├── include/embed.h
├── src/embed.c
├── assets/
│   ├── file1.txt
│   └── fold1/file1.txt
├── xmake.lua
├── local/packages/e/embed/
│   ├── xmake.lua
│   └── port/xmake.lua
├── hook/
│   ├── build.dart
│   └── link.dart
├── lib/
│   ├── embed.dart
│   └── src/native/
│       ├── embed.g.dart
│       ├── embed.record_use_mapping.g.dart
│       └── xmake.dart
└── tool/ffigen.dart
```

`lib/embed.dart` 提供公开的资源 API，`lib/src/native/` 集中存放 FFI 绑定、
使用记录映射和共享的 xmake 配置。`tool/ffigen.dart` 负责生成其中的两个
`.g.dart` 文件，两个 hook 共用 `xmake.dart` 中的配置和 asset ID。

根工程使用单个 `embed` target，并引用仓库中的 `dart_native` 规则包。

根工程和 `local/packages/e/embed/port/xmake.lua` 都显式设置
`configs = {local_source = true}`，从当前 checkout 读取规则源码。
`local_source` 是公共配方的自定义选项；默认模式会按 `dart_native 1.0.0`
下载固定 Git commit 的规则源码。修改本地规则后需要手动提升开发版本或重装
规则包；已发布版本到远程 commit 的映射保持不变。

| 配置 | 包输入与 target 行为 |
| --- | --- |
| `static`，无符号名单 | 构建完整静态包；phony target 安装包产物 |
| `shared`，无符号名单 | 构建并安装导出四个公共 API 的完整动态包 |
| `shared`，有符号名单 | 引用完整静态包；target 控制导出并执行 GC，生成裁剪后的动态库 |

静态包通过 `@dart_native/library` 准备分节和 PIC；最终链接使用
`@dart_native/link`。访问 `Assets.file1Txt.bytes` 时，会保留根资源的两个
入口和数据，未使用的嵌套资源可以被删除。仅保留 `asset_file1_txt_size` 时，
长度是编译期常量，未使用的 `asset_file1_txt_data` 和资源数据也可以被删除。

Windows 静态包使用 `EMBED_STATIC`，共享包使用 `EMBED_BUILDING`；
最终导出集合由链接阶段决定。

## 编译器要求

需要 xmake，以及支持 C23 `#embed` 的 C 编译器。例如
[GCC 15 及以上](https://gcc.gnu.org/gcc-15/changes.html)或
[Clang 19 及以上](https://releases.llvm.org/19.1.0/tools/clang/docs/ReleaseNotes.html)。
`set_languages("c23")` 只选择语言模式，不会为旧编译器补上该特性。

空文件会产生零长度数组，本例已在 GCC 15 默认 C23 模式下验证。这依赖
编译器扩展，严格标准模式会拒绝该写法。

[MSVC 的支持表目前仍将 `#embed` 标为不支持](https://learn.microsoft.com/en-us/cpp/overview/visual-cpp-language-conformance)。
在 macOS 或 Windows 上需要自行选择支持该特性的工具链，不能假定默认的
Apple Clang 或 MSVC 可以编译本例。

## 运行原生示例

在本目录构建完整静态包并运行 C 示例：

```sh
xmake f -c -y --kind=static
xmake build embed
xmake run embed_demo
```

安装完整动态包：

```sh
xmake f -c -y --kind=shared
xmake build embed
xmake install -o dist/shared embed
```

通过命令行只保留长度入口：

```sh
xmake f -c -y --kind=shared --keep_symbols='{"asset_file1_txt_size"}'
xmake build embed
```

`keep_symbols` 是 Lua 字符串列表，和 Dart 传入 xmake 的格式一致。

## Dart hooks

`hook/build.dart` 和 `hook/link.dart` 共用 `lib/src/native/xmake.dart` 的
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

`main.dart` 用 `Assets.file1Txt.bytes` 读取并输出完整文本，使用根资源的两个
原生入口；`size.dart` 直接使用根资源的长度入口；`unused.dart` 不使用原生
API。构建会自动调用 xmake，不需要手动指定动态库路径。

生成的 FFI 绑定已包含在示例里。修改 `include/embed.h` 后重新生成：

```sh
dart run tool/ffigen.dart
```

测试集中在仓库根目录。在满足编译器要求的环境中，从仓库根目录运行：

```sh
dart test test/embed --concurrency=1
```

`test/embed/feature_test.dart` 验证文本、空资源、嵌套二进制资源和副本隔离，
`test/embed/link_test.dart` 验证未使用时省略原生库、按文件裁剪，以及只使用
长度入口时删除资源数据。它们通过 `test/helpers.dart` 共用临时工程准备流程。
[GitHub Actions](../../.github/workflows/project_xmake.yml) 仅在 Linux 上运行
本例测试，使用 Ubuntu 26.04 预装的 GCC 15。

## 修改源码和资源

本地原生包当前声明为 `embed 1.0.0`，xmake 会按包版本和配置复用安装
缓存。修改 `src/`、`include/`、`assets/` 或包的构建描述后，应升级
根工程 `add_requires` 声明的原生包版本。`port/xmake.lua` 的 `set_version`
是原生工程版本信息，不决定包缓存版本。

Dart hook 登记这些输入的依赖变化，但 hook 重新运行本身不会清除 xmake
同版本的包缓存。已编译的程序保留构建时嵌入的资源内容。

本地仓库的锁文件可能包含 checkout 的绝对路径，本例不提交这类路径锁；
依赖版本由 `add_requires` 显式指定。
