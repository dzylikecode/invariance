import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/shared.g.dart' as g;
import 'binding/api.dart';
import 'runtime.dart';

class PyRef.fromHandle(
  var Pointer<g.PyObject> _ptr, {
  required final bool _isBorrowed,
}) {
  Pointer<g.PyObject> get ptr => _ptr;

  factory own(Pointer<g.PyObject> ptr) => .fromHandle(ptr, isBorrowed: false);
  factory borrow(Pointer<g.PyObject> ptr) => .fromHandle(ptr, isBorrowed: true);

  void increment() => api.Py_IncRef(ptr);
  void discrement() => api.Py_DecRef(ptr);

  void dispose() {
    if (_ptr == nullptr) return;
    if (!_isBorrowed) discrement();
    _ptr = nullptr;
  }
}

class const PyObject(final PyRef ref) {
  Pointer<g.PyObject> get ptr => ref.ptr;

  factory own(Pointer<g.PyObject> ptr) => .new(.own(ptr));
  factory borrow(Pointer<g.PyObject> ptr) => .new(.borrow(ptr));

  void dispose() => ref.dispose();

  @override
  String toString() => api.convertToString(ptr);
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
        .own(
          ffi.using(
            (arena) => checked(
              () => api.PyImport_ImportModule(
                moduleName.toNativeUtf8(allocator: arena).cast<Char>(),
              ),
            ),
          ),
        ),
      );
}

/// tuple
///
/// [PyTuple] 会管理接管所有权:
/// {@example /test/tuple_test.dart#tuple-take-the-ownership}
class PyTuple(int size) extends PyObject {
  this : super(.own(api.PyTuple_New(size)));

  int get length => api.PyTuple_Size(ptr);

  /// Set the item at [index] in the tuple to [item].
  ///
  /// [item] 只是被借用，所以不得释放
  void setItem(int index, PyObject item) =>
      checked(() => api.PyTuple_SetItem(ptr, index, item.ptr));

  PyObject getItem(int index) =>
      .borrow(checked(() => api.PyTuple_GetItem(ptr, index)));
}

class PyList(int size) extends PyObject {
  this : super(.own(api.PyList_New(size)));

  void setItem(int index, PyObject item) =>
      checked(() => api.PyList_SetItem(ptr, index, item.ptr));

  PyObject getItem(int index) =>
      .borrow(checked(() => api.PyList_GetItem(ptr, index)));
}
