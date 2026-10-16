import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'package:resource_scope/resource_scope.dart';

import 'binding/shared.g.dart' as g;
import 'binding/api.dart';
import 'runtime.dart';

/// One owned Python reference, automatically registered in the current scope.
///
/// Separate references to the same pointer must use separate PyRef instances.
class PyRef.fromHandle(final Pointer<g.PyObject> _ptr)
    implements ScopedResource {
  bool _disposed = false;

  /// Takes ownership of an existing new reference, without incrementing it.
  this {
    if (_ptr == nullptr) throw ArgumentError('Null Python reference');
    ResourceScope.track(this);
  }

  /// Acquires an independent owned reference from a borrowed pointer.
  factory fromBorrowedHandle(Pointer<g.PyObject> ptr) {
    if (ptr == nullptr) throw ArgumentError('Null Python reference');
    checked(() => api.Py_IncRef(ptr));
    return .fromHandle(ptr);
  }

  /// The native pointer, available only while this reference is alive.
  Pointer<g.PyObject> get ptr {
    if (_disposed) throw StateError('Python reference is disposed');
    return _ptr;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  PyRef detachFromScope() {
    if (isDisposed) throw StateError('Python reference is disposed');
    ResourceScope.untrack(this);
    return this;
  }

  @override
  PyRef detachToParentScope() {
    if (isDisposed) throw StateError('Python reference is disposed');
    ResourceScope.promoteToParent(this);
    return this;
  }

  /// Acquires a separately managed reference to the same Python object.
  PyRef retain() => PyRef.fromBorrowedHandle(ptr);

  /// Acquires a raw reference for transfer to native code. Prefer [retain]
  /// when the new reference should be managed by Dart.
  void increment() => checked(() => api.Py_IncRef(ptr));

  /// Releases this owned reference. Prefer [dispose].
  @Deprecated('Use dispose() for owned references')
  void discrement() => dispose();

  @override
  void dispose() {
    if (_disposed) return;
    checked(() {
      _disposed = true;
      ResourceScope.untrack(this);
      api.Py_DecRef(_ptr);
    });
  }

  @override
  bool operator ==(Object other) => other is PyRef && ptr == other.ptr;

  @override
  int get hashCode => ptr.hashCode;
}

class const PyObject(final PyRef ref) implements ScopedResource {
  Pointer<g.PyObject> get ptr => ref.ptr;

  /// Whether the shared owned reference has been disposed.
  @override
  bool get isDisposed => ref.isDisposed;

  @override
  PyObject detachFromScope() {
    ref.detachFromScope();
    return this;
  }

  @override
  PyObject detachToParentScope() {
    ref.detachToParentScope();
    return this;
  }

  /// Takes ownership of one new reference.
  ///
  /// For aliases, use [PyObject.new] with the existing [ref].
  factory fromHandle(Pointer<g.PyObject> ptr) => .new(.fromHandle(ptr));

  /// Acquires an owned reference from a borrowed native pointer.
  factory fromBorrowedHandle(Pointer<g.PyObject> ptr) =>
      .new(.fromBorrowedHandle(ptr));

  /// Returns an owned reference even though CPython supplies a borrowed one.
  factory borrowedConst(PyConst v) =>
      .fromBorrowedHandle(checked(() => api.Py_GetConstantBorrowed(v)));
  factory getConst(PyConst v) =>
      .fromHandle(checked(() => api.Py_GetConstant(v)));

  /// Acquires a separately scoped reference to this Python object.
  PyObject retain() => PyObject(ref.retain());

  @override
  String toString() => checked(() => api.callToString(ptr));

  @override
  bool operator ==(Object other) => other is PyObject && ref == other.ref;

  @override
  int get hashCode => ref.hashCode;

  @override
  void dispose() => ref.dispose();
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

  int getAttrInt(String attribute) => ResourceScope.scope(() {
    final attr = getAttr(attribute);
    return attr.asInt();
  });
  double getAttrDouble(String attribute) => ResourceScope.scope(() {
    final attr = getAttr(attribute);
    return attr.asDouble();
  });

  bool getAttrBool(String attribute) => ResourceScope.scope(() {
    final attr = getAttr(attribute);
    return attr.asBool();
  });

  String getAttrString(String attribute) => ResourceScope.scope(() {
    final attr = getAttr(attribute);
    return attr.asString();
  });

  PyObject getAttrObject(PyObject attribute) =>
      .fromHandle(checked(() => api.PyObject_GetAttr(ptr, attribute.ptr)));
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

extension PyObjectConverter on PyObject {
  int asInt() => checked(() => api.PyLong_AsLong(ptr));
  double asDouble() => checked(() => api.PyFloat_AsDouble(ptr));
  bool asBool() => checked(() => api.PyObject_IsTrue(ptr) != 0);
  String asString() =>
      checked(() => api.PyUnicode_AsUTF8(ptr)).cast<ffi.Utf8>().toDartString();
}

extension PyObjectCall on PyObject {
  PyObject call(PyTuple args, [PyDict? kwargs]) => .fromHandle(
    checked(
      () => api.PyObject_Call(
        ptr,
        args.ptr,
        kwargs == null ? nullptr : kwargs.ptr,
      ),
    ),
  );
  PyObject call0() =>
      .fromHandle(checked(() => api.PyObject_CallObject(ptr, nullptr)));

  /// Calls with arguments whose ownership remains with the caller.
  PyObject callN(List<PyObject> args) => ResourceScope.returning(() {
    final tuple = PyTuple.fromList(args);
    return call(tuple);
  });
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

/// Object results own a new reference, managed by [ResourceScope.scope].
/// Outside a scope, release results with [PyObject.dispose]. Operands keep their references.
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

  /// python: a @ b
  PyObject matrixMultiply(PyObject other) =>
      .fromHandle(checked(() => api.PyNumber_MatrixMultiply(ptr, other.ptr)));

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

  /// python: a **= b; with modulus: a = pow(a, b, modulus)
  /// Python power, optionally with a modulus. An omitted modulus uses None.
  PyObject inPlacePower(PyObject exponent, [PyObject? modulus]) {
    return .fromHandle(
      checked(
        () => api.PyNumber_InPlacePower(
          ptr,
          exponent.ptr,
          modulus?.ptr ?? api.Py_GetConstantBorrowed(.none),
        ),
      ),
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
  /// Runs a synchronous Python context manager in a temporary resource scope.
  ///
  /// To return a locally created resource beyond this boundary, use its
  /// [PyObject.detachToParentScope] method before returning it.
  T withContext<T>(T Function(PyObject) action) => ResourceScope.scope(() {
    final enter = getAttr('__enter__');
    final value = enter.call0();
    try {
      return action(value);
    } finally {
      final exit = getAttr('__exit__');
      exit.callN([.getConst(.none), .getConst(.none), .getConst(.none)]);
    }
  });
}

/// CPython 会缓存小整数，相同的缓存值（例如 1）共享底层对象和引用计数。
/// 这不代表所有整数都会共享；每次构造仍取得一个需要由调用方释放的引用。
/// 引用计数的具体变化取决于 CPython 版本，不能假定每次构造都会加一。
class PyInt(int value) extends PyObject {
  this : super(.fromHandle(checked(() => api.PyLong_FromLong(value))));
}

/// 每次构造都会创建独立的 Python 浮点对象，即使值相同也不共享引用计数。
/// 新对象的引用计数为 1，调用方需要分别释放各自的引用。
class PyDouble(double value) extends PyObject {
  this : super(.fromHandle(checked(() => api.PyFloat_FromDouble(value))));
}

class PyBool(bool value) extends PyObject {
  this : super(.fromHandle(checked(() => api.PyBool_FromLong(value ? 1 : 0))));
}

class PyString(String value) extends PyObject {
  this
    : super(
        .fromHandle(
          ffi.using(
            (arena) => checked(
              () => api.PyUnicode_FromString(
                value.toNativeUtf8(allocator: arena).cast<Char>(),
              ),
            ),
          ),
        ),
      );
}

class PyModule.fromRef(super.ref) extends PyObject {
  /// Takes ownership of one new native reference.
  factory fromHandle(Pointer<g.PyObject> ptr) => .fromRef(.fromHandle(ptr));

  /// Acquires an owned reference from a borrowed native pointer.
  factory fromBorrowedHandle(Pointer<g.PyObject> ptr) =>
      .fromRef(.fromBorrowedHandle(ptr));

  /// Imports a module and owns a new reference to it.
  factory(String moduleName) => ffi.using(
    (arena) => .fromHandle(
      checked(
        () => api.PyImport_ImportModule(
          moduleName.toNativeUtf8(allocator: arena).cast<Char>(),
        ),
      ),
    ),
  );

  /// Creates a module by compiling and executing [source].
  ///
  /// With [name], registers the module in sys.modules. An existing module's
  /// namespace is reused; execution failure removes that sys.modules entry,
  /// following PyImport_ExecCodeModule semantics. Without [name], creates an
  /// independent module named `_anonymous` without registering it for import.
  /// The caller owns the returned reference. Python errors propagate normally.
  factory fromSource(String source, {String? name}) => ffi.using(
    (arena) => ResourceScope.returning(() {
      final code = PyObject.fromHandle(
        checked(
          () => api.Py_CompileStringExFlags(
            source.toNativeUtf8(allocator: arena).cast<Char>(),
            (name == null ? '<string>' : '<$name>')
                .toNativeUtf8(allocator: arena)
                .cast<Char>(),
            257, // Py_file_input in Python 3.8 through 3.13.
            nullptr,
            -1,
          ),
        ),
      );
      final moduleName = (name ?? '_anonymous')
          .toNativeUtf8(allocator: arena)
          .cast<Char>();
      if (name != null) {
        return PyModule.fromHandle(
          checked(() => api.PyImport_ExecCodeModule(moduleName, code.ptr)),
        );
      }
      final module = PyModule.fromHandle(
        checked(() => api.PyModule_New(moduleName)),
      );
      final globals = checked(
        () => api.PyModule_GetDict(module.ptr),
      ); // Borrowed.
      // Unlike PyImport_ExecCodeModule, PyEval_EvalCode does not inject builtins.
      final builtinsDict = PyObject.fromBorrowedHandle(
        checked(() => api.PyEval_GetBuiltins()),
      ); // Acquire an owned reference to the borrowed builtins dictionary.
      PyDict.fromBorrowedHandle(globals)
          .setElementAtStr('__builtins__', builtinsDict);

      PyObject.fromHandle(
        checked(() => api.PyEval_EvalCode(code.ptr, globals, globals)),
      );
      return module;
    }),
  );
}

/// tuple
///
/// Insertion retains items; the caller keeps its own references:
/// {@example /test/object_test.dart#tuple-take-the-ownership}
class PyTuple.fromRef(super.ref) extends PyObject {
  /// Takes ownership of one new native reference.
  factory fromHandle(Pointer<g.PyObject> ptr) => .fromRef(.fromHandle(ptr));

  /// Acquires an owned reference from a borrowed native pointer.
  factory fromBorrowedHandle(Pointer<g.PyObject> ptr) =>
      .fromRef(.fromBorrowedHandle(ptr));

  factory(int size) => .fromHandle(checked(() => api.PyTuple_New(size)));

  /// Retains each input without consuming the caller's references.
  factory fromList(List<PyObject> items) => ResourceScope.returning(() {
    final tuple = PyTuple(items.length);
    for (var i = 0; i < items.length; i++) {
      tuple.setElementAt(i, items[i]);
    }
    return tuple;
  });

  int get length => checked(() => api.PyTuple_Size(ptr));

  /// Set the item at [index] in the tuple to [item].
  ///
  /// Retains [item]; the caller keeps its existing reference.
  void setElementAt(int index, PyObject item) => checked(() {
    final tuple = ptr;
    final value = item.ptr;
    api.Py_IncRef(value);
    api.PyTuple_SetItem(tuple, index, value);
  });

  /// Returns an independent owned reference.
  PyObject elementAt(int index) => checked(
    () => PyObject.fromBorrowedHandle(
      checked(() => api.PyTuple_GetItem(ptr, index)),
    ),
  );

  void operator []=(int index, PyObject item) => setElementAt(index, item);
  PyObject operator [](int index) => elementAt(index);
}

class PyList.fromRef(super.ref) extends PyObject {
  /// Takes ownership of one new native reference.
  factory fromHandle(Pointer<g.PyObject> ptr) => .fromRef(.fromHandle(ptr));

  /// Acquires an owned reference from a borrowed native pointer.
  factory fromBorrowedHandle(Pointer<g.PyObject> ptr) =>
      .fromRef(.fromBorrowedHandle(ptr));

  factory(int size) => .fromHandle(checked(() => api.PyList_New(size)));

  int get length => checked(() => api.PyList_Size(ptr));

  /// Retains [item]; the caller keeps its existing reference.
  void setElementAt(int index, PyObject item) => checked(() {
    final list = ptr;
    final value = item.ptr;
    api.Py_IncRef(value);
    api.PyList_SetItem(list, index, value);
  });

  /// Returns an independent owned reference.
  PyObject elementAt(int index) => checked(
    () => PyObject.fromBorrowedHandle(
      checked(() => api.PyList_GetItem(ptr, index)),
    ),
  );

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
/// Lookups, copies and snapshot lists return independent owned references.
/// They are automatically managed by the active scope.
class PyDict.fromRef(super.ref) extends PyObject {
  /// Takes ownership of one new native reference.
  factory fromHandle(Pointer<g.PyObject> ptr) => .fromRef(.fromHandle(ptr));

  /// Acquires an owned reference from a borrowed native pointer.
  factory fromBorrowedHandle(Pointer<g.PyObject> ptr) =>
      .fromRef(.fromBorrowedHandle(ptr));

  factory() => .fromHandle(checked(() => api.PyDict_New()));

  int get length => checked(() => api.PyDict_Size(ptr));
  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  /// [key].ref++, [item].ref++
  void setElementAt(PyObject key, PyObject item) =>
      checked(() => api.PyDict_SetItem(ptr, key.ptr, item.ptr));

  /// Returns an independent owned reference.
  PyObject? elementAt(PyObject key) => checked(() {
    final item = checked(() => api.PyDict_GetItem(ptr, key.ptr));
    return item == nullptr ? null : PyObject.fromBorrowedHandle(item);
  });

  bool contains(PyObject key) =>
      checked(() => api.PyDict_Contains(ptr, key.ptr)) != 0;

  /// Deletes [key], throwing a Python KeyError if it is absent.
  void remove(PyObject key) => checked(() => api.PyDict_DelItem(ptr, key.ptr));
  PyObject? elementAtStr(String key) => ffi.using(
    (arena) => checked(() {
      final item = checked(
        () => api.PyDict_GetItemString(
          ptr,
          key.toNativeUtf8(allocator: arena).cast(),
        ),
      );
      return item == nullptr ? null : PyObject.fromBorrowedHandle(item);
    }),
  );
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
