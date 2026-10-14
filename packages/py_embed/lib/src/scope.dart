import 'object.dart';

/// Runs [action] synchronously and performs registered cleanup in reverse order.
///
/// References and deferred callbacks share one order on success and failure.
/// Async callbacks are not supported.
///
/// Returning a registered object does not keep it alive. Use scope.escape()
/// to transfer its reference to the caller. Unregistered results are untouched.
R using<R>(R Function(PyScope scope) action) {
  final scope = PyScope._();
  try {
    return action(scope);
  } finally {
    scope._release();
  }
}

/// A synchronous scope created by [using].
///
/// Registrations represent owned references, not unique Python objects. Each
/// registration requires a separate owned reference, even for the same object.
/// Do not release or transfer a registered reference without escaping it first.
final class PyScope._() {
  final _cleanup = <(PyObject?, void Function())>[];
  bool _closed = false;

  void _checkOpen() {
    if (_closed) throw StateError('Python reference scope has closed');
  }

  /// Takes ownership of one existing reference and returns [object] unchanged.
  /// Does not increment its reference count. Use [retain] for borrowed objects.
  T call<T extends PyObject>(T object) {
    _checkOpen();
    _cleanup.add((object, object.ref.discrement));
    return object;
  }

  /// Acquires and registers a new reference, leaving existing ownership intact.
  T retain<T extends PyObject>(T object) {
    _checkOpen();
    object.ref.increment();
    _cleanup.add((object, object.ref.discrement));
    return object;
  }

  /// Transfers one registered reference to the caller without changing its count.
  ///
  /// Removes the most recent registration of this exact Dart object. Throws if
  /// it is not registered in this scope. Other registrations remain managed.
  /// Escape immediately before return or transfer: later errors no longer cause
  /// this scope to release the escaped reference.
  T escape<T extends PyObject>(T object) {
    _checkOpen();
    final index = _cleanup.lastIndexWhere(
      (entry) => identical(entry.$1, object),
    );
    if (index < 0) {
      throw ArgumentError.value(
        object,
        'object',
        'Not registered in this scope',
      );
    }
    _cleanup.removeAt(index);
    return object;
  }

  /// Registers [action] to run when this scope exits.
  ///
  /// Actions and owned references are cleaned up in reverse registration order.
  /// Cleanup continues after a failure, then rethrows the first cleanup error.
  /// The action must be synchronous.
  void defer(void Function() action) {
    _checkOpen();
    _cleanup.add((null, action));
  }

  void _release() {
    _closed = true;
    Object? firstError;
    StackTrace? firstStack;
    while (_cleanup.isNotEmpty) {
      final action = _cleanup.removeLast().$2;
      try {
        action();
      } catch (error, stack) {
        // A failing release must not skip the remaining registrations.
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }
}
