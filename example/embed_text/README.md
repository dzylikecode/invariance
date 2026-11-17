# 用 C23 `#embed` 嵌入文本

通过 xmake 把 `resources/message.txt` 的 UTF-8 字节编译进程序，再从 C 或
Dart 输出。运行时无需读取或分发这个文本文件。

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

C 示例使用 `fwrite`，Dart 则通过生成的 FFI 绑定取得指针和长度后解码 UTF-8；
两者都不依赖 `strlen`，可以保留资源里原有的 `\0`。指针指向原生库拥有的只读
静态内存，调用方无需释放。

## 运行

需要 xmake，以及支持 C23 `#embed` 的默认编译器。本机的 `gcc`、`g++` 已是
15.3.0，因此只需 `set_languages("c23")`，由 xmake 自动选择工具链。

在本目录运行原生示例：

```sh
xmake
xmake run embed_text_demo
```

沿用仓库的 Dart native assets 构建 hook：

```sh
dart pub get
dart run example/main.dart
dart analyze
```

`dart run` 会自动调用 xmake 构建、安装并关联共享库，不需要手动指定 `.so` 路径。
生成的 FFI 绑定已包含在示例里；修改 C 头文件后重新生成：

```sh
dart run tool/ffigen.dart
```

修改 `resources/message.txt` 后重新运行构建即可更新内容：编译器的依赖文件跟踪
资源，Dart hook 也显式登记了文本依赖。已编译的程序会一直保留构建时的内容。

## 文件

- `resources/message.txt`：实际嵌入的文本资源。
- `src/embed_text.c`、`src/embed_text.h`：`#embed` 和返回指针、长度的 C ABI。
- `example/main.c`：把资源直接编译进可执行文件的原生入口。
- `lib/embed_text.dart`、`example/main.dart`：从原生共享库读取资源的 Dart 入口。
- `tool/ffigen.dart`：生成 FFI 绑定及符号映射。
- `hook/build.dart`：xmake 构建及资源依赖登记。
