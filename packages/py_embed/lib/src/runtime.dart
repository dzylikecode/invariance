import 'package:meta/meta.dart';

import 'binding/cross.dart';
import 'env/env_args.dart';

enum _State { idle, configured, running, shuttingDown, closed }

@internal
final runtime = _Runtime._();

final class _Runtime._() {
  _State state = .idle;

  bool get isInitialized => state == .running;

  void ensureInitialized() {
    switch (state) {
      case .idle || .configured:
        init();
        state = .running;
      case .running:
        return;
      case .shuttingDown:
        throw StateError('Python is shutting down.');
      case .closed:
        throw StateError('Python has already been shut down.');
    }
  }

  void init() {
    final executablePath = getPyExecutableFromShellSync();
    initPy(executablePath);
  }
}
