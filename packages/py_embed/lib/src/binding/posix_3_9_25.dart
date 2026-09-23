import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'posix_3_9_25.g.dart' as g;
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
  Pointer<shared.PyObject> PyTuple_New(int size) => _api.PyTuple_New(size);

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
}

final class Api(super.dynamicLibrary)
    extends shared.NativeLibrary
    with PlatformApi
    implements BaseApi;
