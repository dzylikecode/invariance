import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/api.dart';
import 'env/env_args.dart';
import 'common.dart';

enum _State { idle, running, closed }

final pyRuntime = _Runtime._();

final class _Runtime._() {
  _State state = .idle;

  bool get isInitialized => state == .running;
  Version get version => pyVersion;

  void init([String? executablePath]) {
    switch (state) {
      case .idle:
        executablePath ??= getPyExecutableFromShellSync();
        // !important: 避免循环初始化
        $singleApi.initPy(executablePath);
        state = .running;
      case .running:
        return;
      case .closed:
        throw StateError('Python has already been shut down.');
    }
  }

  T execute<T>(T Function() operation) {
    try {
      final result = operation();
      // TODO: error check
      if (api.getLastError() != 0) {}

      return result;
    } finally {}
  }

  void dispose() {
    if (state == .closed) return;
    if (state == .running) api.Py_Finalize();
    state = .closed;
  }
}

T runPythonZone<T>(T Function() operation) => pyRuntime.execute(operation);

/// execute python code
///
/// {@example ../../example/hello_world.dart}
void runString(String code) => runPythonZone(
  () => ffi.using(
    (arena) => api.PyRun_SimpleString(
      code.toNativeUtf8(allocator: arena).cast<Char>(),
    ),
  ),
);
