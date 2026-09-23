import 'dart:ffi';
import 'dart:io';

import 'object.dart';
import 'binding/shared.g.dart' as g;

final class PyObjectDebugWin extends Struct {
  @LongLong()
  external int count;

  external Pointer<Void> type;
}

final class PyObjectDebugPosix extends Struct {
  @Long()
  external int count;

  external Pointer<Void> type;
}

extension PyObjectDebugExtension on PyObject {
  int get refCount => getRefCount(ptr);
}

int getRefCount(Pointer<g.PyObject> ptr) => Platform.isWindows
    ? ptr.cast<PyObjectDebugWin>().ref.count
    : ptr.cast<PyObjectDebugPosix>().ref.count;
