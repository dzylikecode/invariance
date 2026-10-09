// ignore_for_file: non_constant_identifier_names
import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'posix_3_13_15.g.dart' as g;
import 'utils.dart';
import 'shared.g.dart' as shared;

import '../env/env_args.dart';
import 'api.dart';

final _api = g.NativeLibrary(pyDll);

class _PyConfig._(final Pointer<g.PyConfig> ptr) {
  factory() {
    final ptr = ffi.calloc<g.PyConfig>();
    _api.PyConfig_InitPythonConfig(ptr);
    return ._(ptr);
  }

  /// 由于 dart 无法表达 &config->executable 这种指针的指针类型
  /// 所以这里用一个替身来处理
  Pointer<WChar> _setString(String value, Pointer<WChar> oldValue) =>
      ffi.using((arena) {
        // 让 PyConfig_SetString 负责释放原来的 Python-owned 字符串
        final temp = arena<Pointer<WChar>>()..value = oldValue;
        _api.PyConfig_SetString(
          ptr,
          temp,
          value.toNativeWChar(allocator: arena),
        ).guard();
        return temp.value;
      });

  String get executable => ptr.ref.executable.toDartString();
  set executable(String path) =>
      ptr.ref.executable = _setString(path, ptr.ref.executable);
  // set executable(String path) => ptr.ref.executable = path.toNativeWChar();

  String get programName => ptr.ref.program_name.toDartString();
  set programName(String path) =>
      ptr.ref.program_name = _setString(path, ptr.ref.program_name);
  // set programName(String path) => ptr.ref.program_name = path.toNativeWChar();

  void dispose() {
    _api.PyConfig_Clear(ptr);
    ffi.calloc.free(ptr);
  }
}

mixin PlatformApi on shared.NativeLibrary implements PlatformBaseApi {
  @override
  void initPy(String path) {
    final config = _PyConfig();
    try {
      config
        ..executable = path
        ..programName = path;
      _api.Py_InitializeFromConfig(config.ptr).guard();
    } finally {
      config.dispose();
    }
  }

  @override
  int PyObject_Size(Pointer<shared.PyObject> obj) => _api.PyObject_Size(obj);

  @override
  Pointer<shared.PyObject> PyTuple_New(int size) => _api.PyTuple_New(size);

  @override
  int PyTuple_Size(Pointer<shared.PyObject> obj) => _api.PyTuple_Size(obj);

  @override
  Pointer<shared.PyObject> PyTuple_GetItem(
    Pointer<shared.PyObject> obj,
    int index,
  ) => _api.PyTuple_GetItem(obj, index);

  @override
  int PyTuple_SetItem(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  ) => _api.PyTuple_SetItem(obj, index, item);

  @override
  Pointer<shared.PyObject> PyList_New(int size) => _api.PyList_New(size);

  @override
  int PyList_Size(Pointer<shared.PyObject> obj) => _api.PyList_Size(obj);

  @override
  int PyList_SetItem(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  ) => _api.PyList_SetItem(obj, index, item);

  @override
  Pointer<shared.PyObject> PyList_GetItem(
    Pointer<shared.PyObject> obj,
    int index,
  ) => _api.PyList_GetItem(obj, index);

  @override
  int PyList_Append(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> item,
  ) => _api.PyList_Append(obj, item);

  @override
  int PyList_Insert(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  ) => _api.PyList_Insert(obj, index, item);

  @override
  int PyList_Sort(Pointer<shared.PyObject> obj) => _api.PyList_Sort(obj);

  @override
  int PyList_Reverse(Pointer<shared.PyObject> obj) => _api.PyList_Reverse(obj);

  //-------------------------------------------
  // ## dict

  @override
  Pointer<shared.PyObject> PyDict_New() => _api.PyDict_New();

  @override
  int PyDict_Size(Pointer<shared.PyObject> obj) => _api.PyDict_Size(obj);

  @override
  int PyDict_SetItem(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
    Pointer<shared.PyObject> item,
  ) => _api.PyDict_SetItem(obj, key, item);

  @override
  Pointer<shared.PyObject> PyDict_GetItem(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
  ) => _api.PyDict_GetItem(obj, key);

  @override
  int PyDict_DelItem(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
  ) => _api.PyDict_DelItem(obj, key);

  @override
  void PyDict_Clear(Pointer<shared.PyObject> obj) => _api.PyDict_Clear(obj);

  @override
  int PyDict_Next(
    Pointer<shared.PyObject> obj,
    Pointer<IntPtr> pos,
    Pointer<Pointer<shared.PyObject>> key,
    Pointer<Pointer<shared.PyObject>> value,
  ) => _api.PyDict_Next(obj, pos.cast<g.Py_ssize_t>(), key, value);

  @override
  Pointer<shared.PyObject> PyDict_Keys(Pointer<shared.PyObject> obj) =>
      _api.PyDict_Keys(obj);

  @override
  Pointer<shared.PyObject> PyDict_Values(Pointer<shared.PyObject> obj) =>
      _api.PyDict_Values(obj);

  @override
  Pointer<shared.PyObject> PyDict_Items(Pointer<shared.PyObject> obj) =>
      _api.PyDict_Items(obj);

  @override
  Pointer<shared.PyObject> PyDict_Copy(Pointer<shared.PyObject> obj) =>
      _api.PyDict_Copy(obj);

  @override
  int PyDict_Contains(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> key,
  ) => _api.PyDict_Contains(obj, key);

  @override
  int PyDict_Update(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> other,
  ) => _api.PyDict_Update(obj, other);

  @override
  int PyDict_Merge(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> other,
    int override,
  ) => _api.PyDict_Merge(obj, other, override);

  @override
  Pointer<shared.PyObject> PyDict_GetItemString(
    Pointer<shared.PyObject> obj,
    Pointer<Char> key,
  ) => _api.PyDict_GetItemString(obj, key);

  @override
  int PyDict_SetItemString(
    Pointer<shared.PyObject> obj,
    Pointer<Char> key,
    Pointer<shared.PyObject> item,
  ) => _api.PyDict_SetItemString(obj, key, item);

  @override
  int PyDict_DelItemString(Pointer<shared.PyObject> obj, Pointer<Char> key) =>
      _api.PyDict_DelItemString(obj, key);

  //-------------------------------------------
  // ## sequence

  @override
  int PySequence_DelItem(Pointer<shared.PyObject> obj, int index) =>
      _api.PySequence_DelItem(obj, index);

  @override
  int PySequence_Size(Pointer<shared.PyObject> obj) =>
      _api.PySequence_Size(obj);

  @override
  Pointer<shared.PyObject> PySequence_Concat(
    Pointer<shared.PyObject> obj,
    Pointer<shared.PyObject> other,
  ) => _api.PySequence_Concat(obj, other);

  @override
  Pointer<shared.PyObject> PySequence_Repeat(
    Pointer<shared.PyObject> obj,
    int count,
  ) => _api.PySequence_Repeat(obj, count);

  @override
  Pointer<shared.PyObject> PySequence_GetItem(
    Pointer<shared.PyObject> obj,
    int index,
  ) => _api.PySequence_GetItem(obj, index);

  @override
  int PySequence_SetItem(
    Pointer<shared.PyObject> obj,
    int index,
    Pointer<shared.PyObject> item,
  ) => _api.PySequence_SetItem(obj, index, item);

  @override
  Pointer<shared.PyObject> Py_GetConstantBorrowed(PyConst v) =>
      _api.Py_GetConstantBorrowed(v.value);

  @override
  Pointer<shared.PyObject> Py_GetConstant(PyConst v) =>
      _api.Py_GetConstant(v.value);

}

final class Api(super.dynamicLibrary)
    extends shared.NativeLibrary
    with PlatformApi
    implements BaseApi;
