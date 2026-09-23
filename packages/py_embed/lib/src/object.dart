import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/shared.g.dart' as g;
import 'binding/api.dart';
import 'runtime.dart';

class PyObject.fromHandle(
  var Pointer<g.PyObject> _ptr, {
  final bool _isBorrowed = false,
}) {
  Pointer<g.PyObject> get ptr => _ptr;

  factory own(Pointer<g.PyObject> ptr) => .fromHandle(ptr, isBorrowed: false);
  factory borrow(Pointer<g.PyObject> ptr) => .fromHandle(ptr, isBorrowed: true);

  void dispose() {
    if (_ptr == nullptr) return;
    if (!_isBorrowed) {
      api.Py_DecRef(_ptr);
    }
    _ptr = nullptr;
  }
}

extension PyObjectAttributes on PyObject {
  /// Get the [attribute] of a Python object by name.
  ///
  /// [attribute] must exist, otherwise a [StateError] will be thrown.
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
