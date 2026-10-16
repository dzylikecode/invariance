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

## 自动资源管理

`py_embed` 直接使用并导出 `resource_scope` 的 `ResourceScope` 和
`ScopedResource`。在作用域内创建的 Python 引用自动登记，无需逐个登记对象。
正常返回和异常退出都会清理作用域内的引用；`dispose()` 可提前调用且幂等。

```dart
ResourceScope.scope(() {
  final math = PyModule('math');
  final result = math.getAttr('sqrt').forward([9]);
  print(result.asDouble()); // 3.0
});
```

普通 `scope` 不保留返回的资源。需要返回资源时，使用 `ResourceScope.returning`，
它清理临时对象，并将结果移交给父作用域；没有父作用域时由调用者手动释放。
库内部的 `forward`、转换器和 `PyModule.fromSource` 也使用这个接口。

```dart
final PyList result = ResourceScope.returning(() {
  final list = PyList(0);
  list.add(PyInt(42));
  return list;
});
try {
  print(result);
} finally {
  result.dispose();
}
```

也可以调用 `obj.detachToParentScope()` 显式移交给直接父作用域，或调用
`obj.detachFromScope()` 完全解除当前作用域的管理。对外层资源的操作不会自动
定位其实际拥有者：分离和移交应在创建该引用的作用域中进行。普通 Dart 函数的
`return` 本身不改变所有权，不能依赖资源管理器自动检查跨作用域误用。

`ResourceScope.scope` 支持异步回调，`await` 前后创建的引用属于同一作用域。
所有使用这些引用的异步工作必须被 `await` 或返回；未等待的任务不能延长作用域
生命周期。`ResourceScope.returning` 用于同步返回资源，不能直接接收异步回调。

```dart
await ResourceScope.scope(() async {
  final value = PyDouble(1.5);
  await Future<void>.delayed(Duration.zero);
  print(value.asDouble());
});
```

### 引用与包装

每个 `PyRef` 表示一份拥有的引用，构造时通过 `ResourceScope.track` 自动登记。
`PyObject` 实现 `ScopedResource`，将释放和分离操作委托给其 `PyRef`，因此
`ResourceScope.returning` 可以直接返回包装对象。包装本身不重复登记。

`PyObject(ref)` 和 `PyList.fromRef(ref)` 等共享同一份引用，释放任一别名会让全部
别名失效。需要独立生命周期时，使用 `object.retain()` 或 `object.ref.retain()`，
得到新的、自动登记的引用。`ResourceScope.returning` 保留返回对象的具体类型；
包装对象继承的 `detachFromScope` 和 `detachToParentScope` 返回类型为 `PyObject`。

FFI 边界上，`fromHandle(ptr)` 接管一个新引用；`fromBorrowedHandle(ptr)` 先
`INCREF`，再接管。不要用 `fromHandle(existing.ptr)` 创建别名，否则会为同一份
引用建立两份所有权。已释放对象的 `ptr` 访问会抛出 `StateError`。

在作用域外创建的对象由调用者负责 `dispose()`。需要在活动作用域中重新接管一个
手动拥有的 Python 包装时，使用 `ResourceScope.track(obj.ref)`，登记实际引用。
`ResourceScope.unmanaged(() => ...)` 可临时关闭构造登记；这不影响分配诊断，
对象仍需调用者释放。

### 从旧 PyScope 迁移

- `using((scope) { ... })` 改为 `ResourceScope.scope(() { ... })`。
- 删除 `scope(obj)`；构造和返回 Python 对象的方法都会自动登记。
- 清理临时对象并返回资源的函数使用 `ResourceScope.returning(() { ... })`。
- `scope.escape(obj)` 改为 `obj.detachFromScope()`，或根据意图使用
  `obj.detachToParentScope()` 移交给父作用域。
- `scope.retain(obj)` 改为 `obj.retain()`，使用返回的新包装。
- 使用 `dispose()` 替代 `ref.discrement()`；后者保留为已弃用的幂等释放别名。
- tuple/list 的 setter、`PyTuple.fromList` 和 `callN` 保留调用者的引用，
  不再消耗传入对象；删除为这些调用手动添加的 `increment()`。
- tuple/list/dict 的取值方法现在返回独立拥有的引用，可以在容器释放后继续使用；
  在作用域外使用时，需要自行释放这些取值结果。
- `PyConverter` 对已有 Python 对象返回独立引用，不再返回原包装加裸 `INCREF`。

资源清理采用 `resource_scope` 自身的语义，不保证逆序清理，也没有 `defer`；
清理动作抛错会中断后续清理。需要明确顺序或确保执行的应用级清理使用
`try/finally`，不要依赖资源登记顺序。

### Python 调用 Dart

`PyFunction` 每次回调自动建立一个作用域，清理参数包装和临时对象。直接返回新对象、
参数对象或已有对象即可，桥接层会为 Python 单独保留返回引用；删除旧回调返回前的
手动 `increment()`。需要把对象保存到回调之外时，使用
`value.retain().detachFromScope()`，再由接收方接管或释放。

`PyFunction` 自身也自动登记，释放时同时清理 Python 引用和原生回调内存。Python
必须在函数释放前移除所有对它的引用。额外的 Python 引用或 `retain()` 不会延长
原生回调内存的寿命；若要让函数跨作用域存活，应分离或移交原始函数资源。
Python 若保存了函数引用，使用显式 `try/finally` 先移除这些引用，再释放原始函数。

### 分配追踪

```sh
dart -DTRACK_RESOURCE_ALLOCATIONS=true test --compiler=source --concurrency=1
```

可通过 `ResourceScope.checkNoLeaks()` 检查未释放的登记。
`detachFromScope()` 会移除诊断记录，因此这个检查不是所有存活引用的完整清单。
