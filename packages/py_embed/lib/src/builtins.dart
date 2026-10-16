import 'package:resource_scope/resource_scope.dart';

import 'object.dart';
import 'forward.dart';
import 'binding/api.dart';
import 'runtime.dart';

/// Returns the Python type of [object].
PyObject type(PyObject object) =>
    PyObject.fromHandle(checked(() => api.PyObject_Type(object.ptr)));

/// Creates a class with [name], [bases], and [attributes].
///
/// Equivalent to Python `type(name, bases, dict)`. Bases and attribute values
/// remain owned by the caller; the result owns a new reference.
PyObject newType(
  String name,
  List<PyObject> bases,
  Map<String, Object?> attributes,
) => ResourceScope.returning(() {
  final tuple = PyTuple(bases.length);
  for (var i = 0; i < bases.length; i++) {
    tuple.setElementAt(i, bases[i]);
  }
  return PyObject.fromBorrowedHandle(api.PyType_Type)
      .forward([name, tuple, attributes]);
});

/// Creates a Python `object()` instance owning a new reference.
PyObject object() => ResourceScope.returning(
  () => PyObject.fromBorrowedHandle(api.PyBaseObject_Type).call0(),
);

/// Creates a Python `super(type, object)` proxy owning a new reference.
///
/// Both arguments are explicit; Python's implicit frame-based form is not used.
PyObject superOf(PyObject type, PyObject object) => ResourceScope.returning(
  () => PyObject.fromBorrowedHandle(api.PySuper_Type).forward([type, object]),
);

/// Python `len(object)`. Objects without a length raise TypeError.
int len(PyObject object) => checked(() => api.PyObject_Size(object.ptr));

/// Python `abs(object)`, preserving custom Python return types.
PyObject abs(PyObject object) =>
    .fromHandle(checked(() => api.PyNumber_Absolute(object.ptr)));

/// Python `pow(base, exponent)` or `pow(base, exponent, modulus)`.
PyObject pow(PyObject base, PyObject exponent, [PyObject? modulus]) =>
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
PyObject divmod(PyObject a, PyObject b) =>
    .fromHandle(checked(() => api.PyNumber_Divmod(a.ptr, b.ptr)));

/// Python `repr(object)`, copied into a Dart string.
String repr(PyObject object) => ResourceScope.scope(() {
  final result = PyObject.fromHandle(
    checked(() => api.PyObject_Repr(object.ptr)),
  );
  return result.asString();
});

/// Python `isinstance(object, classInfo)`, including tuples of types.
bool isInstance(PyObject object, PyObject classInfo) =>
    checked(() => api.PyObject_IsInstance(object.ptr, classInfo.ptr)) != 0;

PyObject str(PyObject object) =>
    .fromHandle(checked(() => api.PyObject_Str(object.ptr)));

PyObject ascii(PyObject object) =>
    .fromHandle(checked(() => api.PyObject_ASCII(object.ptr)));
