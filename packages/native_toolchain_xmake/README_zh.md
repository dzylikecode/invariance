# xmake

[英文](README.md) |  [中文](README_zh.md)

为什么不用 cmake?

- 好像是 compile_commands.json 生成的问题？
- 偏好 dart run hello_world 这样的模式；类似的有 xmake run hello_world

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

随包提供的 [dart-xmake 技能](skills/dart-xmake/SKILL.md) 涵盖原生工程准备、
Dart build hook 和原生代码裁剪。

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
        assetName: 'src/native/project_xmake.g.dart',
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
      assetName: 'src/native/project_xmake.g.dart',
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

## xmake

- [xmake 与 dart hook](../../example/project_xmake/)
- [嵌入资源文件](../../example/embed/)

## 开发

针对智能:

- 记得同步不同语言的 README.md

## issue

- [x] [hooks 丢失环境变量](https://github.com/dart-lang/native/issues/3304)
- [x] [交叉编译问题](https://github.com/dart-lang/sdk/issues/63953)
- [x] [tree-shaking 在 windows 上失败](https://github.com/dart-lang/native/pull/3773)
- [x] tree-shaking 的交叉编译仍需验证，包括 Zig 工具链兼容性。


存在的问题：

- 如果debug的时候，xmake正在下载程序，但是因为网络中断了，会导致比如curl子程序成为孤立的进程占用文件

    用可以查看用下面命令查看，然后 kill 相关程序

    ```bash
    xmake -vD
    ```


