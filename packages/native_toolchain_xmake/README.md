# xmake

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

忘记为什么不用 cmake 了。好像是 compile_commands.json 生成的问题？

用 zig 交叉编译

[install zig](https://ziglang.org/learn/getting-started/#managers)

```bash
winget install -e --id zig.zig
```

```bash
brew install zig
```

应该用 zigcc 作为toolchain 而不是 zig


mac 用bash安装会找不到命令，而用 brew install xmake 是可以的

如果debug的时候，xmake正在下载程序，然后自己中断了，会导致比如curl子程序成为孤立的进程占用文件

用

```bash
xmake -vD
```

可以查看
