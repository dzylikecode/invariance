import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'package:meta/meta.dart';

import 'binding/cross.dart';
import 'env/env_args.dart';
import 'binding/shared.dart';

enum _State { idle, running, closed }

final pyRuntime = _Runtime._();

final class _Runtime._() {
  _State state = .idle;

  bool get isInitialized => state == .running;

  void _ensureInitialized() {
    switch (state) {
      case .idle:
        init();
        state = .running;
      case .running:
        return;
      case .closed:
        throw StateError('Python has already been shut down.');
    }
  }

  void init([String? executablePath]) {
    executablePath ??= getPyExecutableFromShellSync();
    initPy(executablePath);
  }

  T execute<T>(T Function() operation) {
    _ensureInitialized();
    try {
      final result = operation();
      // TODO: error check
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

void runString(String code) => runPythonZone(
  () => ffi.using(
    (arena) => api.PyRun_SimpleString(
      code.toNativeUtf8(allocator: arena).cast<Char>(),
    ),
  ),
);
