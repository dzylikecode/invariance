import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'shared.g.dart' as g;
import 'api.dart';

extension PyStatusExt on g.PyStatus {
  bool get isException =>
      $singleApi.PyStatus_Exception(this) != 0; // $singleApi 切断循环链
  String get message => err_msg.cast<ffi.Utf8>().toDartString();
  void guard() {
    if (isException) {
      throw this;
    }
  }
}

class const PyException({
  required final String type,
  required final String message,
}) {
  @override
  String toString() => 'Python Exception: $type: $message';
}

extension ApiExt on BaseApi {
  PyException? getLastError() => ffi.using((arena) {
    if (PyErr_Occurred() == nullptr) return null;

    final typePtr = arena<Pointer<g.PyObject>>();
    final valuePtr = arena<Pointer<g.PyObject>>();
    final tracebackPtr = arena<Pointer<g.PyObject>>();

    try {
      PyErr_Fetch(typePtr, valuePtr, tracebackPtr);
      PyErr_NormalizeException(typePtr, valuePtr, tracebackPtr);
      PyErr_Print();
      return PyException(
        type: convertToString(typePtr.value),
        message: convertToString(valuePtr.value),
      );
    } finally {
      Py_XDECREF(typePtr.value);
      Py_XDECREF(valuePtr.value);
      Py_XDECREF(tracebackPtr.value);
    }
  });

  String convertToString(Pointer<g.PyObject> obj) {
    if (obj == nullptr) {
      throw StateError('Cannot convert null PyObject to string');
    }

    final strObj = PyObject_Str(obj);

    if (strObj == nullptr) {
      throw StateError('Failed to convert PyObject to string');
    }

    try {
      // 这个是 borrowed，不需要释放
      final utf8 = PyUnicode_AsUTF8(strObj);
      if (utf8 == nullptr) {
        throw StateError('Failed to convert PyObject to UTF-8 string');
      }
      return utf8.cast<ffi.Utf8>().toDartString();
    } finally {
      api.Py_DecRef(strObj);
    }
  }

  void Py_XDECREF(Pointer<g.PyObject> obj) {
    if (obj != nullptr) {
      Py_DecRef(obj);
    }
  }
}
