import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'windows.g.dart' as g;
import 'utils.dart';

import '../env/dylib.dart';

final api = g.NativeLibrary(dll);

class _PyConfig._(final Pointer<g.PyConfig> ptr) {
  factory() {
    final ptr = ffi.calloc<g.PyConfig>();
    api.PyConfig_InitPythonConfig(ptr);
    return ._(ptr);
  }

  /// 由于 dart 无法表达 &config->executable 这种指针的指针类型
  /// 所以这里用一个替身来处理
  Pointer<WChar> _setString(String value, Pointer<WChar> oldValue) => ffi.using(
    (arena) {
      // 让 PyConfig_SetString 负责释放原来的 Python-owned 字符串
      final temp = arena<Pointer<WChar>>()..value = oldValue;
      // TODO: guard
      api.PyConfig_SetString(ptr, temp, value.toNativeWChar(allocator: arena));
      return temp.value;
    },
  );

  String get executable => ptr.ref.executable.toDartString();
  set executable(String path) =>
      ptr.ref.executable = _setString(path, ptr.ref.executable);
  // set executable(String path) => ptr.ref.executable = path.toNativeWChar();

  String get programName => ptr.ref.program_name.toDartString();
  set programName(String path) =>
      ptr.ref.program_name = _setString(path, ptr.ref.program_name);
  // set programName(String path) => ptr.ref.program_name = path.toNativeWChar();

  void dispose() {
    api.PyConfig_Clear(ptr);
    ffi.calloc.free(ptr);
  }
}

void initPy(String path) {
  final config = _PyConfig()
    ..executable = path
    ..programName = path;
  try {
    // TODO:
    api.Py_InitializeFromConfig(config.ptr);
  } finally {
    config.dispose();
  }
}
