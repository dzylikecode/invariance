import 'object.dart';

/// Helpers for scoped Python reference ownership.
abstract final class Py {
  /// Runs [action] synchronously, releasing registered references in reverse
  /// order on both success and failure. Async callbacks are not supported.
  ///
  /// Returning a registered object does not keep it alive. Use scope.escape()
  /// to transfer its reference to the caller. Unregistered results are untouched.
  static R using<R>(R Function(PyScope scope) action) {
    final scope = PyScope._();
    try {
      return action(scope);
    } finally {
      scope._release();
    }
  }
}

/// A synchronous scope created by [Py.using].
///
/// Registrations represent owned references, not unique Python objects. Each
/// registration requires a separate owned reference, even for the same object.
/// Do not release or transfer a registered reference without escaping it first.
final class PyScope {
  final _references = <PyObject>[];
  bool _closed = false;
  PyScope._();

  void _checkOpen() {
    if (_closed) throw StateError('Python reference scope has closed');
  }

  /// Takes ownership of one existing reference and returns [object] unchanged.
  /// Does not increment its reference count. Use [retain] for borrowed objects.
  T call<T extends PyObject>(T object) {
    _checkOpen();
    _references.add(object);
    return object;
  }

  /// Acquires and registers a new reference, leaving existing ownership intact.
  T retain<T extends PyObject>(T object) {
    _checkOpen();
    object.ref.increment();
    _references.add(object);
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
    final index = _references.lastIndexWhere((item) => identical(item, object));
    if (index < 0) {
      throw ArgumentError.value(
        object,
        'object',
        'Not registered in this scope',
      );
    }
    _references.removeAt(index);
    return object;
  }

  void _release() {
    _closed = true;
    Object? firstError;
    StackTrace? firstStack;
    while (_references.isNotEmpty) {
      final object = _references.removeLast();
      try {
        object.ref.discrement();
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
