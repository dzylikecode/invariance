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

  factory own(Pointer<g.PyObject> ptr) =>
      PyObject.fromHandle(ptr, isBorrowed: false);
  factory borrow(Pointer<g.PyObject> ptr) =>
      PyObject.fromHandle(ptr, isBorrowed: true);

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
  PyObject get(String attribute) => runPythonZone(
    () => ffi.using((arena) {
      final obj = api.PyObject_GetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      );
      if (obj == nullptr) {
        // throw StateError('Attribute "$attribute" not found on Python object.');
      }
      return .fromHandle(obj);
    }),
  );

  void set(String attribute, PyObject value) => runPythonZone(
    () => ffi.using((arena) {
      final result = api.PyObject_SetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      );
      if (result != 0) {
        // throwPythonException(context: "setting attribute '$attribute'");
      }
    }),
  );

  bool has(String attribute) => runPythonZone(
    () => ffi.using((arena) {
      final result = api.PyObject_HasAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      );
      return result != 0;
    }),
  );

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
  int toInt() => runPythonZone(() => api.PyLong_AsLong(ptr));
  double toDouble() => runPythonZone(() => api.PyFloat_AsDouble(ptr));
  bool toBool() => runPythonZone(() => api.PyObject_IsTrue(ptr) != 0);
}
