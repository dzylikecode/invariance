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

extension on Pointer<g.PyObject> {
  PyRef get asRef => .fromHandle(this);
  PyObject get asObj => .fromHandle(this);
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

/// CPython 会缓存小整数，相同的缓存值（例如 1）共享底层对象和引用计数。
/// 这不代表所有整数都会共享；每次构造仍取得一个需要由调用方释放的引用。
/// 引用计数的具体变化取决于 CPython 版本，不能假定每次构造都会加一。
class PyInt(int value) extends PyObject {
  this : super(.fromHandle(api.PyLong_FromLong(value)));
}

/// 每次构造都会创建独立的 Python 浮点对象，即使值相同也不共享引用计数。
/// 新对象的引用计数为 1，调用方需要分别释放各自的引用。
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

class PyList.fromHandle(Pointer<g.PyObject> ptr) extends PyObject {
  this : super(.fromHandle(ptr));

  factory(int size) => .fromHandle(checked(() => api.PyList_New(size)));

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

/// A Python dictionary. Keys and values are retained when inserted.
///
/// Lookups return borrowed references, like [PyList.elementAt]. Do not release
/// them unless you first call [PyRef.increment]; they are valid only while the
/// dictionary retains the value. Copies and snapshot lists own new references
/// and must be released by their caller.
class PyDict.fromHandle(Pointer<g.PyObject> ptr) extends PyObject {
  this : super(.fromHandle(ptr));

  factory() => .fromHandle(checked(() => api.PyDict_New()));

  int get length => checked(() => api.PyDict_Size(ptr));
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  /// Retains [key] and [item]; the caller keeps its own references.
  void setElementAt(PyObject key, PyObject item) =>
      checked(() => api.PyDict_SetItem(ptr, key.ptr, item.ptr));

  /// Returns a borrowed reference, or null if [key] is absent.
  PyObject? elementAt(PyObject key) {
    final item = checked(() => api.PyDict_GetItem(ptr, key.ptr));
    return item == nullptr ? null : .fromHandle(item);
  }

  bool contains(PyObject key) =>
      checked(() => api.PyDict_Contains(ptr, key.ptr)) != 0;

  /// Deletes [key], throwing a Python KeyError if it is absent.
  void remove(PyObject key) => checked(() => api.PyDict_DelItem(ptr, key.ptr));

  void clear() => checked(() => api.PyDict_Clear(ptr));

  /// A new list containing the keys. The caller owns the list reference.
  PyList get keys => .fromHandle(checked(() => api.PyDict_Keys(ptr)));

  /// A new list containing the values. The caller owns the list reference.
  PyList get values => .fromHandle(checked(() => api.PyDict_Values(ptr)));

  /// A new list of (key, value) tuples. The caller owns the list reference.
  PyList get items => .fromHandle(checked(() => api.PyDict_Items(ptr)));

  /// A shallow copy. The caller owns the returned dictionary reference.
  PyDict copy() => .fromHandle(checked(() => api.PyDict_Copy(ptr)));

  /// Adds entries from [other], replacing existing values.
  void update(PyDict other) => checked(() => api.PyDict_Update(ptr, other.ptr));

  /// Adds entries from [other], optionally keeping existing values.
  void merge(PyDict other, {bool override = true}) =>
      checked(() => api.PyDict_Merge(ptr, other.ptr, override ? 1 : 0));

  void operator []=(PyObject key, PyObject item) => setElementAt(key, item);
  PyObject? operator [](PyObject key) => elementAt(key);
}
