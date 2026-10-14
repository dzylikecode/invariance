import 'object.dart';
import 'forward.dart';
import 'binding/api.dart';
import 'runtime.dart';
import 'scope.dart' as scopes;
import 'scope.dart' show PyScope;

abstract final class Py {
  /// Returns the Python type of [object].
  static PyObject type(PyObject object) =>
      PyObject.fromHandle(api.PyObject_Type(object.ptr));

  /// Creates a class with [name], [bases], and [attributes].
  ///
  /// Equivalent to Python `type(name, bases, dict)`. Bases and attribute values
  /// remain owned by the caller; the result owns a new reference.
  static PyObject newType(
    String name,
    List<PyObject> bases,
    Map<String, Object?> attributes,
  ) => using((scope) {
    final tuple = scope(PyTuple(bases.length));
    for (var i = 0; i < bases.length; i++) {
      bases[i].ref.increment();
      tuple.setElementAt(i, bases[i]);
    }
    return .fromHandle(api.PyType_Type).forward([name, tuple, attributes]);
  });

  /// Creates a Python `object()` instance owning a new reference.
  static PyObject object() => .fromHandle(api.PyBaseObject_Type).call0();

  /// Creates a Python `super(type, object)` proxy owning a new reference.
  ///
  /// Both arguments are explicit; Python's implicit frame-based form is not used.
  static PyObject superOf(PyObject type, PyObject object) =>
      .fromHandle(api.PySuper_Type).forward([type, object]);

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

  static PyObject str(PyObject object) =>
      .fromHandle(checked(() => api.PyObject_Str(object.ptr)));

  static PyObject ascii(PyObject object) =>
      .fromHandle(checked(() => api.PyObject_ASCII(object.ptr)));

  /// Runs [action] synchronously in a Python reference scope.
  ///
  /// See [scopes.using] for ownership and escape semantics.
  static R using<R>(R Function(PyScope scope) action) => scopes.using(action);
}
