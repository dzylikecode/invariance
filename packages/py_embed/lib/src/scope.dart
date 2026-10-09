import 'object.dart';
import 'binding/api.dart';
import 'runtime.dart';

/// Python built-ins and scoped reference ownership.
///
/// Built-ins borrow their arguments. PyObject results own a new reference;
/// register them with [using] or release them with [PyRef.discrement].
abstract final class Py {
  /// Python `len(object)`. Objects without a length raise TypeError.
  static int len(PyObject object) =>
      checked(() => api.PyObject_Size(object.ptr));

  /// Python `abs(object)`, preserving custom Python return types.
  static PyObject abs(PyObject object) =>
      .fromHandle(checked(() => api.PyNumber_Absolute(object.ptr)));

  /// Python `pow(base, exponent)` or `pow(base, exponent, modulus)`.
  static PyObject pow(PyObject base, PyObject exponent, [PyObject? modulus]) =>
      .fromHandle(
        checked(
          () => api.PyNumber_Power(
            base.ptr,
            exponent.ptr,
            modulus?.ptr ?? api.Py_GetConstantBorrowed(.none),
          ),
        ),
      );

  /// Python `divmod(a, b)`, preserving custom Python return types.
  static PyObject divmod(PyObject a, PyObject b) =>
      .fromHandle(checked(() => api.PyNumber_Divmod(a.ptr, b.ptr)));

  /// Python `repr(object)`, copied into a Dart string.
  static String repr(PyObject object) => using((scope) {
    final result = scope(
      PyObject.fromHandle(checked(() => api.PyObject_Repr(object.ptr))),
    );
    return result.asString();
  });

  /// Python `isinstance(object, classInfo)`, including tuples of types.
  static bool isInstance(PyObject object, PyObject classInfo) =>
      checked(() => api.PyObject_IsInstance(object.ptr, classInfo.ptr)) != 0;

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
