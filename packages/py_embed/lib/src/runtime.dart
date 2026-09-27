import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'binding/api.dart';
import 'env/env_args.dart';
import 'common.dart';

import 'binding/shared.g.dart' as g;

final pyRuntime = _Runtime._();

final class _Runtime._() {

  /// 跨线程检查进程内 python 的状态
  /// 
  /// 这个对于多个 isolate 引用 pyRuntime 是有用的，比如
  /// dart run test 会启用引用 pyRuntime 。但是它们 dart 级别是不同
  /// 而 c api 端又是同一个，因此在这里用 dart 来保存状态是无效的，
  /// 必须通过 c api 来访问
  bool get isInitialized => $singleApi.Py_IsInitialized() != 0;

  Version get version => pyVersion;
  late final Pointer<g.PyThreadState> _threadState;

  void init([String? executablePath]) {
    if (isInitialized) return;

    executablePath ??= getPyExecutableFromShellSync();
    // !important: 避免循环初始化
    $singleApi.initPy(executablePath);
    // _threadState = $singleApi.PyEval_SaveThread();
  }

  void dispose() {
    if (!isInitialized) return;
    api.Py_Finalize();
  }
}

@internal
T checked<T>(T Function() operation) {
  // final state = api.PyGILState_Ensure();
  try {
    final result = operation();
    if (api.getLastError() case final PyException error) {
      throw error;
    }

    return result;
  } finally {
    // api.PyGILState_Release(state);
  }
}

/// execute python code
///
/// {@example ../../example/hello_world.dart}
void runString(String code) => ffi.using(
  (arena) => checked(
    () => api.PyRun_SimpleString(
      code.toNativeUtf8(allocator: arena).cast<Char>(),
    ),
  ),
);
