import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

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

  void dispose() {
    if (state == .closed) return;
    if (state == .running) api.Py_Finalize();
    state = .closed;
  }
}

@internal
T checked<T>(T Function() operation) {
  try {
    final result = operation();
    if (api.getLastError() case final PyException error) {
      throw error;
    }

    return result;
  } finally {}
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
