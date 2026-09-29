import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/shared.g.dart' as g;
import 'binding/api.dart';
import 'runtime.dart';

import '../debug.dart';

class PyRef.fromHandle(final Pointer<g.PyObject> _ptr) {
  this : assert(_ptr != nullptr);

  Pointer<g.PyObject> get ptr => _ptr;

  void increment() => checked(() => api.Py_IncRef(ptr));
  void discrement() {
    assert(count > 0);
    checked(() => api.Py_DecRef(ptr));
  }
}

class const PyObject(final PyRef ref) {
  Pointer<g.PyObject> get ptr => ref.ptr;

  factory fromHandle(Pointer<g.PyObject> ptr) => .new(.fromHandle(ptr));

  @override
  String toString() => api.convertToString(ptr);
}

extension PyObjectAttributes on PyObject {
  /// Get the [attribute] of a Python object by name.
  ///
  /// [attribute] must exist, otherwise a [StateError] will be thrown.
  /// returns a new [PyObject] that must be disposed of when no longer needed.
  PyObject get(String attribute) => ffi.using(
    (arena) => .fromHandle(
      checked(
        () => api.PyObject_GetAttrString(
          ptr,
          attribute.toNativeUtf8(allocator: arena).cast<Char>(),
        ),
      ),
    ),
  );

  /// Set the [attribute] of a Python object to a new [value].
  void set(String attribute, PyObject value) => ffi.using(
    (arena) => checked(
      () => api.PyObject_SetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      ),
    ),
  );

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
      attr.ref.discrement();
    }
  }

  double getDouble(String attribute) {
    final attr = get(attribute);
    try {
      return attr.toDouble();
    } finally {
      attr.ref.discrement();
    }
  }

  bool getBool(String attribute) {
    final attr = get(attribute);
    try {
      return attr.toBool();
    } finally {
      attr.ref.discrement();
    }
  }
}

extension PyObjectConverter on PyObject {
  int toInt() => checked(() => api.PyLong_AsLong(ptr));
  double toDouble() => checked(() => api.PyFloat_AsDouble(ptr));
  bool toBool() => checked(() => api.PyObject_IsTrue(ptr) != 0);
}

extension PyObjectCall on PyObject {
  PyObject call(PyTuple args, [PyDict? kwargs]) => checked(
    () => .fromHandle(
      api.PyObject_Call(ptr, args.ptr, kwargs == null ? nullptr : kwargs.ptr),
    ),
  );
  PyObject call0() =>
      checked(() => .fromHandle(api.PyObject_CallObject(ptr, nullptr)));
}

class PyInt(int value) extends PyObject {
  this : super(.fromHandle(api.PyLong_FromLong(value)));
}

class PyDouble(double value) extends PyObject {
  this : super(.fromHandle(api.PyFloat_FromDouble(value)));
}

class PyBool(bool value) extends PyObject {
  this : super(.fromHandle(api.PyBool_FromLong(value ? 1 : 0)));
}

class PyString(String value) extends PyObject {
  this
    : super(
        .fromHandle(
          ffi.using(
            (arena) => api.PyUnicode_FromString(
              value.toNativeUtf8(allocator: arena).cast<Char>(),
            ),
          ),
        ),
      );
}

class PyModule(String moduleName) extends PyObject {
  this
    : super(
        .fromHandle(
          ffi.using(
            (arena) => checked(
              () => api.PyImport_ImportModule(
                moduleName.toNativeUtf8(allocator: arena).cast<Char>(),
              ),
            ),
          ),
        ),
      );
}

/// tuple
///
/// [PyTuple] 会管理接管所有权:
/// {@example /test/object_test.dart#tuple-take-the-ownership}
class PyTuple(int size) extends PyObject {
  this : super(.fromHandle(checked(() => api.PyTuple_New(size))));

  int get length => checked(() => api.PyTuple_Size(ptr));

  /// Set the item at [index] in the tuple to [item].
  ///
  /// [item] 只是被借用，所以不得释放
  void setElementAt(int index, PyObject item) =>
      checked(() => api.PyTuple_SetItem(ptr, index, item.ptr));

  PyObject elementAt(int index) =>
      .fromHandle(checked(() => api.PyTuple_GetItem(ptr, index)));

  void operator []=(int index, PyObject item) => setElementAt(index, item);
  PyObject operator [](int index) => elementAt(index);
}

class PyList(int size) extends PyObject {
  this : super(.fromHandle(checked(() => api.PyList_New(size))));

  int get length => checked(() => api.PyList_Size(ptr));

  void setElementAt(int index, PyObject item) =>
      checked(() => api.PyList_SetItem(ptr, index, item.ptr));

  PyObject elementAt(int index) =>
      .fromHandle(checked(() => api.PyList_GetItem(ptr, index)));

  /// ref++
  void add(PyObject item) => checked(() => api.PyList_Append(ptr, item.ptr));

  /// ref++
  void insert(int index, PyObject item) =>
      checked(() => checked(() => api.PyList_Insert(ptr, index, item.ptr)));

  void sort() => checked(() => api.PyList_Sort(ptr));

  void reverse() => checked(() => api.PyList_Reverse(ptr));

  void operator []=(int index, PyObject item) => setElementAt(index, item);
  PyObject operator [](int index) => elementAt(index);
}

class PyDict(int size) extends PyObject {
  this : super(.fromHandle(api.PyList_New(size)));
}
