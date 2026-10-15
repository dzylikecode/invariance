# py embed

- 选择了 python 就不要在意速度，而是实现


## quick start

```bash
conda activate rl
dart run g1
```

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

conda create -n py_embed_3_13_15 python=3.13.15 pip

conda activate py_embed_3_13_15
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

## TODO

参考 [ndarray](https://github.com/google/scientific_dart) 设计


```dart
using((scope) {
  final a = PyInt(1);
  final b = PyInt(2);
  scope.defer(() => print("hello world"));
  return scope.escape(a + b);
});
```

### Modules from source strings

```dart
using((scope) {
  final module = scope(PyModule.fromSource('''
class Model:
    def forward(self, x):
        return x + 1
''', name: 'my_model'));
  final constructor = scope(module.getAttr('Model'));
  final model = scope(constructor.call0());
});
```

With `name`, the module is registered in `sys.modules` and can be imported with
`PyModule(name)`. Reusing a name executes in the existing module namespace;
execution failure removes that registry entry, matching
`PyImport_ExecCodeModule`. Releasing the Dart wrapper does not unregister it.
Omit `name` for an independent module named `_anonymous` that is not registered.
Both forms return a new owned reference and propagate Python exceptions.

Pickled instances of named classes still require the same module/class to be
recreated before loading in a new process; the source string is not embedded in
pickle. See `example/module_from_source.dart`.
