import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/shared.g.dart' as g;
import 'binding/api.dart';
import 'runtime.dart';

class PyRef.fromHandle(
  var Pointer<g.PyObject> _ref, {
  required final bool _isBorrowed,
}) {
  Pointer<g.PyObject> get ptr => _ref;

  factory own(Pointer<g.PyObject> ptr) => .fromHandle(ptr, isBorrowed: false);
  factory borrow(Pointer<g.PyObject> ptr) => .fromHandle(ptr, isBorrowed: true);

  void dispose() {
    if (_ref == nullptr) return;
    if (!_isBorrowed) {
      api.Py_DecRef(_ref);
    }
    _ref = nullptr;
  }
}

class PyObject(final PyRef _ptr) {
  Pointer<g.PyObject> get ptr => _ptr.ptr;

  factory own(Pointer<g.PyObject> ptr) => .new(.own(ptr));
  factory borrow(Pointer<g.PyObject> ptr) => .new(.borrow(ptr));

  void dispose() => _ptr.dispose();

  @override
  String toString() {
    final strObj = api.PyObject_Str(ptr);

    if (strObj == nullptr) {
      throw StateError('Failed to convert PyObject to string');
    }

    try {
      final utf8 = api.PyUnicode_AsUTF8(strObj);
      if (utf8 == nullptr) {
        throw StateError('Failed to convert PyObject to UTF-8 string');
      }
      return utf8.cast<ffi.Utf8>().toDartString();
    } finally {
      api.Py_DecRef(strObj);
    }
  }
}

extension PyObjectAttributes on PyObject {
  /// Get the [attribute] of a Python object by name.
  ///
  /// [attribute] must exist, otherwise a [StateError] will be thrown.
  /// returns a new [PyObject] that must be disposed of when no longer needed.
  PyObject get(String attribute) => ffi.using((arena) {
    final obj = checked(
      () => api.PyObject_GetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    );
    if (obj == nullptr) {
      throw StateError('Attribute "$attribute" not found');
    }
    return .own(obj);
  });

  /// Set the [attribute] of a Python object to a new [value].
  void set(String attribute, PyObject value) => ffi.using((arena) {
    final result = checked(
      () => api.PyObject_SetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      ),
    );
    if (result != 0) {
      throw StateError('Failed to set attribute "$attribute"');
    }
  });

  bool has(String attribute) => ffi.using((arena) {
    final result = checked(
      () => api.PyObject_HasAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    );
    return result != 0;
  });

  int getInt(String attribute) {
    final attr = get(attribute);
    try {
      return attr.toInt();
    } finally {
      attr.dispose();
    }
  }

  double getDouble(String attribute) {
    final attr = get(attribute);
    try {
      return attr.toDouble();
    } finally {
      attr.dispose();
    }
  }

  bool getBool(String attribute) {
    final attr = get(attribute);
    try {
      return attr.toBool();
    } finally {
      attr.dispose();
    }
  }
}

extension PyObjectConverter on PyObject {
  int toInt() => checked(() => api.PyLong_AsLong(ptr));
  double toDouble() => checked(() => api.PyFloat_AsDouble(ptr));
  bool toBool() => checked(() => api.PyObject_IsTrue(ptr) != 0);
}

class PyInt(int value) extends PyObject {
  this : super(.own(api.PyLong_FromLong(value)));
}

class PyDouble(double value) extends PyObject {
  this : super(.own(api.PyFloat_FromDouble(value)));
}

class PyBool(bool value) extends PyObject {
  this : super(.own(api.PyBool_FromLong(value ? 1 : 0)));
}

class PyString(String value) extends PyObject {
  this
    : super(
        .own(
          ffi.using(
            (arena) => api.PyUnicode_FromString(
              value.toNativeUtf8(allocator: arena).cast<Char>(),
            ),
          ),
        ),
      );
}

class PyModule(String moduleName) extends PyObject {
  this
    : super(
        .own(ffi.using((arena) {
          final name = PyString(moduleName);
          try {
            final module = checked(() => api.PyImport_Import(name.ptr));
            if (module == nullptr) {
              throw StateError('Failed to import Python module "$moduleName"');
            }
            return module;
          } finally {
            name.dispose();
          }
        }))
      );
}
