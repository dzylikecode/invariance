# py embed

- 选择了 python 就不要在意速度，而是实现


## quick start

```bash
conda activate rl
dart run g1
```

## Python 内置函数

通过 `Py` 调用内置函数：`Py.len(obj)`、`Py.abs(obj)`、
`Py.pow(base, exponent, [modulus])`、`Py.divmod(a, b)`、
`Py.repr(obj)` 和 `Py.isInstance(obj, classInfo)`。
其中 `len`、`repr`、`isInstance` 分别返回 Dart 的 `int`、`String`、`bool`。
其他函数返回拥有新引用的 `PyObject`，应交给 `Py.using` 管理；参数引用不会被消耗。

```dart
Py.using((scope) {
  final value = scope(PyInt(-7));
  final absolute = scope(Py.abs(value));
  print(absolute.asInt()); // 7
  print(Py.len(scope(PyString('你好😀')))); // 3
});
```

原先的 `obj.abs()`、`obj.pow(...)`、`obj.divmod(...)` 改为上述 `Py` 入口。
容器的 `.length`、对象运算符和 `inPlacePower` 保持原有用法。

## env

miniconda:

- windows

  ```bash
  winget install Anaconda.Miniconda3
  # path/to/conda.bat
  conda init powershell
  ```

- mac

  ```bash
  brew install --cask miniconda
  conda init "$(basename "${SHELL}")"
  ```

> [!NOTE]
>
> ```bash
> conda config --set auto_activate false
> ```


## develop


```bash
conda create -n py_embed_3_8_20 python=3.8.20 pip

conda activate py_embed_3_8_20

conda create -n py_embed_3_9_25 python=3.9.25 pip

conda activate py_embed_3_9_25
```

> 选取 3.8.20 是因为 mac M 系列只支持部分的 3.8，所以就干脆只有最后一个版本

### update platform api

1. 更新各个版本的 cpp, 然后运行 ffigen.dart
2. 在 api.dart 提出需要的 PlatformBaseApi
3. 在 version.dart.template 中实现，然后再运行 ffigen.dart

## issue

这里由于没有处理好并发

```bash
dart run test --concurrency=1
```

## xmake

> [!NOTE]
>
> 这里的 xmake 这是为了用来生成 compile_commands.json 给 IDE 提示用的
> 执行 xmake build 出错无妨
