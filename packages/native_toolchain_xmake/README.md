# xmake

## install

```bash
dart run native_toolchain_xmake:install
```

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


## config

android

```bash
xmake f --plat=android --arch=x86_64 --toolchain=ndk --ndk="C:/Users/<you>/AppData/Local/Android/Sdk/ndk/<version>" --mode=release --kind=shared -y
```

windows:

```bash
xmake f --plat=windows --arch=x64 --mode=release --kind=shared -y
```

## example

```dart
void main(List<String> args) async {
  await build(args, (input, output) async {
    final xmakeBuilder = await XmakeBuilder.create(
      project: input.packageRoot.toFilePath(),
      packageName: input.packageName,
      codeConfig: input.config.code,
    );

    await xmakeBuilder.config();
    await xmakeBuilder.build(target: 'minimal');
    final installedPath = await xmakeBuilder.install(target: 'minimal');

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/cserialport.g.dart',
        file: .file(installedPath),
        linkMode: DynamicLoadingBundled(),
      ),
    );

    output.dependencies.add(input.packageRoot.resolve('xmake.lua'));
  });
}
```

## issue

- [x] [hooks 丢失环境变量](https://github.com/dart-lang/native/issues/3304)
- [ ] [交叉编译问题](https://github.com/dart-lang/sdk/issues/63953)
- [ ] tree-shaking

忘记为什么不用 cmake 了。好像是 compile_commands.json 生成的问题？

用 zig 交叉编译

[install zig](https://ziglang.org/learn/getting-started/#managers)

```bash
winget install -e --id zig.zig
```

```bash
brew install zig
```

如果debug的时候，xmake正在下载程序，然后自己中断了，会导致比如curl子程序成为孤立的进程占用文件

用

```bash
xmake -vD
```

可以查看
