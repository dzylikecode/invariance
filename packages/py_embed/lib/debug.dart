import 'dart:ffi';
import 'dart:io';

import 'src/object.dart';
import 'src/binding/shared.g.dart' as g;

final class _PyObjectDebugWin extends Struct {
  @LongLong()
  external int count;

  external Pointer<Void> type;
}

final class _PyObjectDebugPosix extends Struct {
  @Long()
  external int count;

  external Pointer<Void> type;
}

extension PyObjectDebugExtension on PyObject {
  int get refCount => getRefCount(ptr);
}

int getRefCount(Pointer<g.PyObject> ptr) => Platform.isWindows
    ? ptr.cast<_PyObjectDebugWin>().ref.count
    : ptr.cast<_PyObjectDebugPosix>().ref.count;
