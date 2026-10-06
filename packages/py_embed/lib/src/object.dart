import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/shared.g.dart' as g;
import 'binding/api.dart';
import 'env/env_args.dart' show pyDll;
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
  String toString() => checked(() => api.callToString(ptr));
}

extension PyObjectAttributes on PyObject {
  /// Get the [attribute] of a Python object.
  ///
  /// ```python
  /// obj.attribute
  /// ```
  ///
  /// ref++
  PyObject getAttr(String attribute) => ffi.using(
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
  void setAttr(String attribute, PyObject value) => ffi.using(
    (arena) => checked(
      () => api.PyObject_SetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      ),
    ),
  );

  bool hasAttr(String attribute) => ffi.using((arena) {
    final result = checked(
      () => api.PyObject_HasAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    );
    return result != 0;
  });

  int getAttrInt(String attribute) =>
      getAttr(attribute).using((attr) => attr.asInt());
  double getAttrDouble(String attribute) =>
      getAttr(attribute).using((attr) => attr.asDouble());

  bool getAttrBool(String attribute) =>
      getAttr(attribute).using((attr) => attr.asBool());

  String getAttrString(String attribute) =>
      getAttr(attribute).using((attr) => attr.asString());

  PyObject getAttrObject(PyObject attribute) =>
      checked(() => .fromHandle(api.PyObject_GetAttr(ptr, attribute.ptr)));
  void setAttrObject(PyObject attribute, PyObject value) =>
      checked(() => api.PyObject_SetAttr(ptr, attribute.ptr, value.ptr));
  bool hasAttrObject(PyObject attribute) =>
      checked(() => api.PyObject_HasAttr(ptr, attribute.ptr)) != 0;

  /// Get the item of a Python object using the subscript operator.
  ///
  /// ```python
  /// obj[key]
  /// ```
  ///
  /// ref++
  PyObject getItem(PyObject key) =>
      .fromHandle(checked(() => api.PyObject_GetItem(ptr, key.ptr)));
  void setItem(PyObject key, PyObject value) =>
      checked(() => api.PyObject_SetItem(ptr, key.ptr, value.ptr));
  void deleteItem(PyObject key) =>
      checked(() => api.PyObject_DelItem(ptr, key.ptr));
}

extension PyObjectReference on PyObject {
  /// 同步执行 [action]，结束时释放当前拥有的一次引用，即使回调抛出异常。
  /// 不增加引用计数，因此不能直接用于 borrowed reference。
  /// 回调不得释放或转交这次引用；异步回调也不会被等待。
  T using<T>(T Function(PyObject) action) {
    try {
      return action(this);
    } finally {
      ref.discrement();
    }
  }
}

extension PyObjectConverter on PyObject {
  int asInt() => checked(() => api.PyLong_AsLong(ptr));
  double asDouble() => checked(() => api.PyFloat_AsDouble(ptr));
  bool asBool() => checked(() => api.PyObject_IsTrue(ptr) != 0);
  String asString() =>
      checked(() => api.PyUnicode_AsUTF8(ptr)).cast<ffi.Utf8>().toDartString();
}

extension PyObjectCall on PyObject {
  PyObject call(PyTuple args, [PyDict? kwargs]) => checked(
    () => .fromHandle(
      api.PyObject_Call(ptr, args.ptr, kwargs == null ? nullptr : kwargs.ptr),
    ),
  );
  PyObject call0() =>
      checked(() => .fromHandle(api.PyObject_CallObject(ptr, nullptr)));

  /// ref-- args 里面的引用会释放一次
  PyObject callN(List<PyObject> args) =>
      PyTuple.fromList(args).using((tuple) => call(tuple as PyTuple));
}

/// Python rich comparison operation codes.
enum PyComparison {
  lessThan,
  lessThanOrEqual,
  equal,
  notEqual,
  greaterThan,
  greaterThanOrEqual,
}

/// Object results own a new reference; release them with [PyObjectReference.using]
/// or [PyRef.discrement]. Operands retain their existing references.
/// Dart compound assignments use the ordinary operators. Use the inPlace
/// methods explicitly for Python augmented assignment semantics.
extension PyObjectOperator on PyObject {
  /// python: a + b
  PyObject operator +(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Add(ptr, other.ptr)));

  /// python: a - b
  PyObject operator -(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Subtract(ptr, other.ptr)));

  /// python: a * b
  PyObject operator *(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Multiply(ptr, other.ptr)));

  /// python: a / b
  PyObject operator /(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_TrueDivide(ptr, other.ptr)));

  /// python: a // b
  PyObject operator ~/(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_FloorDivide(ptr, other.ptr)));

  /// python: a % b
  PyObject operator %(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Remainder(ptr, other.ptr)));

  /// python: a << b
  PyObject operator <<(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Lshift(ptr, other.ptr)));

  /// python: a >> b
  PyObject operator >>(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Rshift(ptr, other.ptr)));

  /// python: a & b
  PyObject operator &(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_And(ptr, other.ptr)));

  /// python: a ^ b
  PyObject operator ^(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Xor(ptr, other.ptr)));

  /// python: a | b
  PyObject operator |(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Or(ptr, other.ptr)));

  /// python: -a
  PyObject operator -() =>
      .fromHandle(checked(() => api.PyNumber_Negative(ptr)));

  /// python: ~a
  PyObject operator ~() => .fromHandle(checked(() => api.PyNumber_Invert(ptr)));

  /// python: +a
  PyObject positive() => .fromHandle(checked(() => api.PyNumber_Positive(ptr)));

  /// python: abs(a)
  PyObject abs() => .fromHandle(checked(() => api.PyNumber_Absolute(ptr)));

  /// python: a @ b
  PyObject matrixMultiply(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_MatrixMultiply(ptr, other.ptr)));

  /// python: divmod(a, b)
  PyObject divmod(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_Divmod(ptr, other.ptr)));

  /// python: a += b
  PyObject inPlaceAdd(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceAdd(ptr, other.ptr)));

  /// python: a -= b
  PyObject inPlaceSubtract(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceSubtract(ptr, other.ptr)));

  /// python: a *= b
  PyObject inPlaceMultiply(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceMultiply(ptr, other.ptr)));

  /// python: a @= b
  PyObject inPlaceMatrixMultiply(PyObject other) => .fromHandle(
    checked(() => api.PyNumber_InPlaceMatrixMultiply(ptr, other.ptr)),
  );

  /// python: a //= b
  PyObject inPlaceFloorDivide(PyObject other) => .fromHandle(
    checked(() => api.PyNumber_InPlaceFloorDivide(ptr, other.ptr)),
  );

  /// python: a /= b
  PyObject inPlaceTrueDivide(PyObject other) => .fromHandle(
    checked(() => api.PyNumber_InPlaceTrueDivide(ptr, other.ptr)),
  );

  /// python: a %= b
  PyObject inPlaceRemainder(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceRemainder(ptr, other.ptr)));

  /// python: a <<= b
  PyObject inPlaceLshift(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceLshift(ptr, other.ptr)));

  /// python: a >>= b
  PyObject inPlaceRshift(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceRshift(ptr, other.ptr)));

  /// python: a &= b
  PyObject inPlaceAnd(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceAnd(ptr, other.ptr)));

  /// python: a ^= b
  PyObject inPlaceXor(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceXor(ptr, other.ptr)));

  /// python: a |= b
  PyObject inPlaceOr(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_InPlaceOr(ptr, other.ptr)));

  /// python: a ** b; with modulus: pow(a, b, modulus)
  /// Python power, optionally with a modulus. An omitted modulus uses None.
  PyObject pow(PyObject exponent, [PyObject? modulus]) {
    modulus ??= PyNone.borrowed;
    return .fromHandle(
      checked(() => api.PyNumber_Power(ptr, exponent.ptr, modulus!.ptr)),
    );
  }

  /// python: a **= b; with modulus: a = pow(a, b, modulus)
  /// Python power, optionally with a modulus. An omitted modulus uses None.
  PyObject inPlacePower(PyObject exponent, [PyObject? modulus]) {
    modulus ??= PyNone.borrowed;
    return .fromHandle(
      checked(() => api.PyNumber_InPlacePower(ptr, exponent.ptr, modulus!.ptr)),
    );
  }

  /// python: a < b, a <= b, a == b, a != b, a > b, a >= b (by comparison)
  /// Preserves custom comparison results, such as array masks.
  PyObject richCompare(PyObject other, PyComparison comparison) => .fromHandle(
    checked(() => api.PyObject_RichCompare(ptr, other.ptr, comparison.index)),
  );

  /// python: bool(a < b), bool(a <= b), bool(a == b), bool(a != b), bool(a > b), bool(a >= b) (by comparison)
  bool compare(PyObject other, PyComparison comparison) =>
      checked(
        () => api.PyObject_RichCompareBool(ptr, other.ptr, comparison.index),
      ) !=
      0;

  // Extensions cannot override Object.==; use these methods for Python equality.
  /// python: a == b
  bool equals(PyObject other) => compare(other, .equal);

  /// python: a != b
  bool notEquals(PyObject other) => compare(other, .notEqual);

  /// python: a < b
  bool operator <(PyObject other) => compare(other, .lessThan);

  /// python: a <= b
  bool operator <=(PyObject other) => compare(other, .lessThanOrEqual);

  /// python: a > b
  bool operator >(PyObject other) => compare(other, .greaterThan);

  /// python: a >= b
  bool operator >=(PyObject other) => compare(other, .greaterThanOrEqual);
}

extension PyObjectWithContext on PyObject {
  T withContext<T>(T Function(PyObject) action) {
    final value = getAttr('__enter__').using((enter) => enter.call0());
    try {
      return action(value);
    } finally {
      getAttr('__exit__')
          .using((exit) => exit.callN([PyNone(), PyNone(), PyNone()]));
      value.ref.discrement();
    }
  }
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

/// python: None
/// 所有实例共享 Python 的 None 单例；构造返回 borrowed reference，不增加引用计数。
/// 不要直接调用 .using() 或 ref.discrement()；需要拥有引用时先调用 ref.increment()。
/// 借用引用仅在 Python 解释器存活期间有效。
class PyNone extends PyObject {
  // Py_None 是宏；CPython 导出的数据符号地址就是 None 对象的指针。
  // TODO：移入到 api 中，兼容一下 3.13
  static final _ptr = pyDll.lookup<g.PyObject>('_Py_NoneStruct');

  static final borrowed = PyNone._borrowed();
  factory() {
    final obj = PyNone.borrowed;
    checked(() => obj.ref.increment());
    return obj;
  }
  PyNone._borrowed() : super(.fromHandle(checked(() => _ptr)));
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
class PyTuple.fromHandle(Pointer<g.PyObject> ptr) extends PyObject {
  this : super(.fromHandle(ptr));

  factory(int size) => .fromHandle(checked(() => api.PyTuple_New(size)));

  /// ref==
  factory fromList(List<PyObject> items) {
    final tuple = PyTuple(items.length);
    for (var i = 0; i < items.length; i++) {
      tuple.setElementAt(i, items[i]);
    }
    return tuple;
  }

  int get length => checked(() => api.PyTuple_Size(ptr));

  /// Set the item at [index] in the tuple to [item].
  ///
  /// ref ==
  void setElementAt(int index, PyObject item) =>
      checked(() => api.PyTuple_SetItem(ptr, index, item.ptr));

  /// ref ==
  PyObject elementAt(int index) =>
      .fromHandle(checked(() => api.PyTuple_GetItem(ptr, index)));

  void operator []=(int index, PyObject item) => setElementAt(index, item);
  PyObject operator [](int index) => elementAt(index);
}

class PyList.fromHandle(Pointer<g.PyObject> ptr) extends PyObject {
  this : super(.fromHandle(ptr));

  factory(int size) => .fromHandle(checked(() => api.PyList_New(size)));

  int get length => checked(() => api.PyList_Size(ptr));

  /// ref ==
  void setElementAt(int index, PyObject item) =>
      checked(() => api.PyList_SetItem(ptr, index, item.ptr));

  /// ref ==
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

  /// [key].ref++, [item].ref++
  void setElementAt(PyObject key, PyObject item) =>
      checked(() => api.PyDict_SetItem(ptr, key.ptr, item.ptr));

  /// ref ==
  PyObject? elementAt(PyObject key) {
    final item = checked(() => api.PyDict_GetItem(ptr, key.ptr));
    return item == nullptr ? null : .fromHandle(item);
  }

  bool contains(PyObject key) =>
      checked(() => api.PyDict_Contains(ptr, key.ptr)) != 0;

  /// Deletes [key], throwing a Python KeyError if it is absent.
  void remove(PyObject key) => checked(() => api.PyDict_DelItem(ptr, key.ptr));
  PyObject? elementAtStr(String key) => ffi.using((arena) {
    final item = checked(
      () => api.PyDict_GetItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast(),
      ),
    );
    return item == nullptr ? null : .fromHandle(item);
  });
  void setElementAtStr(String key, PyObject item) => ffi.using(
    (arena) => checked(
      () => api.PyDict_SetItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast(),
        item.ptr,
      ),
    ),
  );
  void removeStr(String key) => ffi.using(
    (arena) => checked(
      () => api.PyDict_DelItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast(),
      ),
    ),
  );

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
