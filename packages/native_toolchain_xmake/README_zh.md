# xmake

[英文](README.md) |  [中文](README_zh.md)

为什么不用 cmake?

- 好像是 compile_commands.json 生成的问题？
- 我更喜欢 dart run hello_world 这样的模式；类似的，xmake run hello_world

## 环境依赖

1. 安装 xmake

```bash
dart run native_toolchain_xmake:install
```

本质上是执行这些：

- windows:

  ```bash
  irm https://xmake.io/psget.text | iex
  ```

- linux

  ```bash
  curl -fsSL https://xmake.io/shget.text | bash
  ```

  或者

  ```bash
  wget https://xmake.io/shget.text -O - | bash
  ```

- mac:

  ```bash
  brew install xmake
  ```

  > [!NOTE]
  >
  > 用官网的 bash 反而会陷入找不到库


2. 如果需要交叉编译的话，安装 zig。这个库默认用 zig 来交叉编译


    [install zig](https://ziglang.org/learn/getting-started/#managers)


    - windows

      ```bash
      winget install -e --id zig.zig
      ```

    - mac

      ```bash
      brew install zig
      ```

## Agent skill

```bash
dart run skills@ get -p native_toolchain_xmake
```

## 例子

```dart
// build.dart
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      // flutter need to check this flag
      await XmakeLibrary(
        target: 'project_xmake',
        libHintName: 'project_xmake',
        assetName: 'src/project_xmake.g.dart',
      ).build(input: input, output: output);
    }
  });
}
```

```dart
// link.dart
void main(List<String> args) async {
  await link(args, (input, output) async {
    await XmakeLibrary(
      target: 'project_xmake',
      libHintName: 'project_xmake',
      assetName: 'src/project_xmake.g.dart',
    ).link(
      input: input,
      output: output,
      symbolsToKeep: input.recordedUses?.calls.keys.cast<Method>().map(
        (e) => recordUseMapping[e.name]!,
      ) ?? recordUseMapping.values,
    );
  });
}
```

## xmake 补充知识

`build` 和 `link` 调用同一个 `target`，按配置选择三个分支：

| 阶段 | `kind` | `keep_symbols` | 原生包 | target 行为 |
| --- | --- | --- | --- | --- |
| 启用 linking 的 build | `static` | 无 | 静态包 | phony target 安装完整归档 |
| 直接打包的 build | `shared` | 无 | 动态包 | phony target 安装完整动态库 |
| link | `shared` | 有 | 静态包 | shared target 链接并裁剪最终动态库 |

`symbolsToKeep` 必须
传入列表，为空列表时跳过整个库。没有使用记录时，由 Dart hook 显式传入
`recordUseMapping.values`，保留全部绑定接口。link 产物默认安装到 hook 的
输出目录下。

Dart 将 `keep_symbols` 作为 Lua table literal 字符串传递，例如
`{"add","subtract"}`。link 规则使用 `string.deserialize` 还原 table，
原生符号名称来自 Dart binding mapping。

### 使用 `dart_native` 共享原生构建规则

xmake 规则包 `dart_native 1.0.0` 默认从固定 Git commit 下载规则源码。
每个使用规则的 xmake 工程都需要注册仓库并声明版本依赖：

```lua
add_repositories("dart-native https://github.com/dzylikecode/invariance.git")
add_requires("dart_native 1.0.0", {system = false})
```

三条规则用于原生源码工程，以及两个 hook 共用的单个 target。原生源码工程：

```lua
local kind = get_config("kind") or "static"
target("foo")
    set_kind(kind)
    add_packages("dart_native")
    add_rules("@dart_native/library", {kind = kind})
    add_files("src/*.c")
```

Dart hooks 使用的工程：

```lua
local kind = get_config("kind") or "static"
option("keep_symbols")
    set_showmenu(true)
option_end()

local keepSymbols = get_config("keep_symbols")
add_requires("foo 1.0.0", {
    system = false,
    configs = {shared = kind == "shared" and not keepSymbols, pic = true}
})

target("foo")
    add_packages("foo", "dart_native")
    if kind == "shared" and keepSymbols then
        set_kind("shared")
        add_rules("@dart_native/link", {symbols = keepSymbols})
    else
        set_kind("phony")
        add_rules("@dart_native/install", {package = "foo"})
    end
```

原生包需要提供静态和动态两种形态，仅在 `kind == "shared"` 且没有符号列表
时选择动态包。`keep_symbols` option 没有默认值；同一个 target 仅在 shared
模式且有符号列表时执行真实动态链接。library 规则准备
函数和数据的 section GC，install 规则安装选中的包，link 规则控制最终动态库的
导出与 GC。C API 宏仍由原生工程管理：交给 link hook 的静态输入应避免强制
`dllexport` 或保留属性。

两个 hook 的 `XmakeLibrary` 都使用 `target: 'foo'`。

公共配方 `packages/d/dart_native/xmake.lua` 将 `1.0.0` 映射到 invariance
Git 仓库的 `c241d2c9efcf6fbd1ab5d47614cb8614fec14fc2` commit。
调用方只写版本，由配方指定源码 commit。已发布版本的映射保持不变，更换源码
commit 时应发布新版本。

在当前 checkout 开发规则时，可使用自定义包选项 `local_source`，显式选择
`packages/native_toolchain_xmake/xmake/` 中的源码：

```lua
add_repositories("dart-native ../..", {rootdir = os.scriptdir()})
add_requires("dart_native 1.0.0", {
    system = false,
    configs = {local_source = true}
})
```

以上相对路径适用于 `example/foo/`，其他布局需要调整。消费工程与原生源码
工程都需要显式开启该选项。`project_xmake` 和 `embed_text` 示例使用本地模式；
`template_adapter` 使用当前索引及默认的远程源码。修改本地源码后，需手动提升
开发版本或显式重装规则包，以刷新缓存。
修改 library 编译规则后，也需要提升原生包版本或强制重装原生包，让已有归档
采用新的编译选项。

xmake 使用流程：configure -> build -> install

### config

android

```bash
xmake f --plat=android --arch=x86_64 --toolchain=ndk --ndk="C:/Users/<you>/AppData/Local/Android/Sdk/ndk/<version>" --mode=release --kind=shared -y
```

windows:

```bash
xmake f --plat=windows --arch=x64 --mode=release --kind=shared -y
```

## 开发

针对智能:

- 记得同步不同语言的 README.md

## issue

- [x] [hooks 丢失环境变量](https://github.com/dart-lang/native/issues/3304)
- [x] [交叉编译问题](https://github.com/dart-lang/sdk/issues/63953)
- [x] [tree-shaking 在 windows 上失败](https://github.com/dart-lang/native/pull/3773)
- [ ] tree-shaking 的交叉编译仍需验证，包括 Zig 工具链兼容性。


存在的问题：

- 如果debug的时候，xmake正在下载程序，但是因为网络中断了，会导致比如curl子程序成为孤立的进程占用文件

    用可以查看用下面命令查看，然后 kill 相关程序

    ```bash
    xmake -vD
    ```


