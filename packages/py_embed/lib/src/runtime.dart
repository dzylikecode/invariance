import 'dart:collection';
import 'dart:ffi';

import 'package:meta/meta.dart';

import 'binding/cross.dart';
import 'env/env_args.dart';
import 'binding/shared.g.dart' as g;
import 'binding/shared.dart';

enum _State { idle, running, closed }


@internal
final runtime = _Runtime._();

final class _Runtime._() {
  _State state = .idle;

  bool get isInitialized => state == .running;

  void ensureInitialized() {
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

  void init() {
    final executablePath = getPyExecutableFromShellSync();
    initPy(executablePath);
  }

  T execute<T>(T Function() operation) {
    ensureInitialized();
    try {
      final result = operation();
      // TODO: error check
      return result;
    } finally {}
  }

  void dispose() {
    if (state == .closed) return;

    api.Py_Finalize();
    state = .closed;
  }
}
