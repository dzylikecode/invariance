// ignore_for_file: non_constant_identifier_names
import 'dart:io';
import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'windows_3_8_20.dart' as windows_3_8_20;
import 'posix_3_8_20.dart' as posix_3_8_20;
import 'windows_3_9_25.dart' as windows_3_9_25;
import 'posix_3_9_25.dart' as posix_3_9_25;
import 'windows_3_10_21.dart' as windows_3_10_21;
import 'posix_3_10_21.dart' as posix_3_10_21;
import 'windows_3_11_16.dart' as windows_3_11_16;
import 'posix_3_11_16.dart' as posix_3_11_16;
import 'windows_3_12_14.dart' as windows_3_12_14;
import 'posix_3_12_14.dart' as posix_3_12_14;
import 'windows_3_13_15.dart' as windows_3_13_15;
import 'posix_3_13_15.dart' as posix_3_13_15;
import 'shared.g.dart' as shared;
import '../env/env_args.dart';

import '../runtime.dart';

/// 避免循环依赖创建的，只是在 [pyRuntime].init() 的时候使用
///
/// [getApi] -> [pyRuntime].init() -> [$singleApi].initPy() -> gurad()
@internal
final $singleApi = _getApi();

/// 对于 native 的统一接口
@internal
final api = getApi();

abstract class PlatformBaseApi {
  void initPy(String path);

  int PyObject_Size(Pointer<shared.PyObject> obj);

  //-------------------------------------------
  // ## tuple

  /// 由于 PySize 不同
  Pointer<shared.PyObject> PyTuple_New(int size);
  int PyTuple_Size(Pointer<shared.PyObject> obj);
  int PyTuple_SetItem(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  );
  Pointer<shared.PyObject> PyTuple_GetItem(
    Pointer<shared.PyObject> obj,
    int index,
  );

  //-------------------------------------------
  // ## list

  Pointer<shared.PyObject> PyList_New(int size);
  int PyList_Size(Pointer<shared.PyObject> obj);
  int PyList_SetItem(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  );
  Pointer<shared.PyObject> PyList_GetItem(
    Pointer<shared.PyObject> obj,
    int index,
  );
  int PyList_Append(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> item,
  );
  int PyList_Insert(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  );
  int PyList_Sort(Pointer<shared.PyObject> obj);
  int PyList_Reverse(Pointer<shared.PyObject> obj);

  //-------------------------------------------
  // ## dict

  Pointer<shared.PyObject> PyDict_New();
  int PyDict_Size(Pointer<shared.PyObject> obj);
  int PyDict_SetItem(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
    Pointer<shared.PyObject> item,
  );
  Pointer<shared.PyObject> PyDict_GetItem(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
  );
  int PyDict_DelItem(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
  );
  void PyDict_Clear(Pointer<shared.PyObject> obj);
  int PyDict_Next(
    Pointer<shared.PyObject> obj,
    Pointer<IntPtr> pos,
    Pointer<Pointer<shared.PyObject>> key,
    Pointer<Pointer<shared.PyObject>> value,
  );
  Pointer<shared.PyObject> PyDict_Keys(Pointer<shared.PyObject> obj);
  Pointer<shared.PyObject> PyDict_Values(Pointer<shared.PyObject> obj);
  Pointer<shared.PyObject> PyDict_Items(Pointer<shared.PyObject> obj);
  Pointer<shared.PyObject> PyDict_Copy(Pointer<shared.PyObject> obj);
  int PyDict_Contains(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
  );
  int PyDict_Update(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> other,
  );
  int PyDict_Merge(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> other,
    int override,
  );
  Pointer<shared.PyObject> PyDict_GetItemString(
    Pointer<shared.PyObject> obj,
    Pointer<Char> key,
  );
  int PyDict_SetItemString(
    Pointer<shared.PyObject> obj,
    Pointer<Char> key,
    Pointer<shared.PyObject> item,
  );
  int PyDict_DelItemString(Pointer<shared.PyObject> obj, Pointer<Char> key);

  //-------------------------------------------
  // ## sequence

  int PySequence_DelItem(Pointer<shared.PyObject> obj, int index);
  int PySequence_Size(Pointer<shared.PyObject> obj);
  Pointer<shared.PyObject> PySequence_Concat(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> other,
  );
  Pointer<shared.PyObject> PySequence_Repeat(
    Pointer<shared.PyObject> obj,
    int count,
  );
  Pointer<shared.PyObject> PySequence_GetItem(
    Pointer<shared.PyObject> obj,
    int index,
  );
  int PySequence_SetItem(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  );

  Pointer<shared.PyObject> Py_GetConstantBorrowed(PyConst v);
  Pointer<shared.PyObject> Py_GetConstant(PyConst v);
}

abstract interface class BaseApi
    implements shared.NativeLibrary, PlatformBaseApi;

BaseApi _getApi() =>
    switch ((pyVersion.major, pyVersion.minor, pyVersion.patch)) {
      (3, 8, _) when Platform.isWindows => windows_3_8_20.Api(pyDll),
      (3, 8, _) when !Platform.isWindows => posix_3_8_20.Api(pyDll),
      (3, 9, _) when Platform.isWindows => windows_3_9_25.Api(pyDll),
      (3, 9, _) when !Platform.isWindows => posix_3_9_25.Api(pyDll),
      (3, 10, _) when Platform.isWindows => windows_3_10_21.Api(pyDll),
      (3, 10, _) when !Platform.isWindows => posix_3_10_21.Api(pyDll),
      (3, 11, _) when Platform.isWindows => windows_3_11_16.Api(pyDll),
      (3, 11, _) when !Platform.isWindows => posix_3_11_16.Api(pyDll),
      (3, 12, _) when Platform.isWindows => windows_3_12_14.Api(pyDll),
      (3, 12, _) when !Platform.isWindows => posix_3_12_14.Api(pyDll),
      (3, 13, _) when Platform.isWindows => windows_3_13_15.Api(pyDll),
      (3, 13, _) when !Platform.isWindows => posix_3_13_15.Api(pyDll),
      _ => throw UnimplementedError('$pyVersion is not supported now'),
    };

BaseApi getApi() {
  pyRuntime.init();
  return $singleApi;
}

extension PyStatusExt on shared.PyStatus {
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

    final typePtr = arena<Pointer<shared.PyObject>>();
    final valuePtr = arena<Pointer<shared.PyObject>>();
    final tracebackPtr = arena<Pointer<shared.PyObject>>();

    try {
      PyErr_Fetch(typePtr, valuePtr, tracebackPtr);
      PyErr_NormalizeException(typePtr, valuePtr, tracebackPtr);
      PyErr_Print();
      return PyException(
        type: callToString(typePtr.value),
        message: callToString(valuePtr.value),
      );
    } finally {
      Py_XDECREF(typePtr.value);
      Py_XDECREF(valuePtr.value);
      Py_XDECREF(tracebackPtr.value);
    }
  });

  String callToString(Pointer<shared.PyObject> obj) {
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

  void Py_XDECREF(Pointer<shared.PyObject> obj) {
    if (obj != nullptr) {
      Py_DecRef(obj);
    }
  }
}
/// Constant identifiers for Python's Py_GetConstant APIs.
enum const PyConst(final int value) {
  none(0),
  falseValue(1),
  trueValue(2),
  ellipsis(3),
  notImplemented(4),
  zero(5),
  one(6),
  emptyStr(7),
  emptyBytes(8),
  emptyTuple(9);
}
