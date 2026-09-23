// ignore_for_file: non_constant_identifier_names
import 'dart:io';
import 'dart:ffi';

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

export 'shared.dart';

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
