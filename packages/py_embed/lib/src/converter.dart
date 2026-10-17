import 'dart:collection';

import 'package:resource_scope/resource_scope.dart';

import 'object.dart';

/// A Dart object that holds a Python object by composition.
///
/// Implementations manage the wrapped object's lifetime. This interface does
/// not impose a constructor or a disposal strategy.
abstract interface class PyObjectWrapper {
  /// A borrowed reference to the wrapped object; reading this getter must not
  /// increment its reference count. The object must be alive when returned.
  /// Implementations should throw StateError if their wrapper was disposed.
  PyObject get handle;
}

/// Converts Dart values to owned Python references.
///
/// Extend this class and override [toPyObject] for domain-specific types, then
/// delegate remaining values to super.toPyObject(value). Nested list elements
/// and map keys/values dispatch through the override as well.
///
/// Each successful conversion returns one owned reference. Existing PyObject and PyObjectWrapper
/// values are retained, never consumed. The caller must release the result,
/// including when it represents Python None. Overrides follow the same contract
/// and must clean up their allocations if they throw.
///
/// A converter can be reused after success or failure. Cyclic List/Map values
/// are rejected; repeated containers are converted independently. Strings use
/// PyString's existing conversion semantics.
class PyConverter {
  final _active = HashSet<Object>.identity();

  /// Converts [value], throwing ArgumentError for unsupported types.
  PyObject toPyObject(Object? value) {
    if (value is PyObjectWrapper) {
      // Read once: the getter may perform lifetime validation.
      final handle = value.handle;
      return handle.retain();
    }
    if (value is PyObject) {
      return value.retain();
    }
    return switch (value) {
      null => .getConst(.none),
      bool v => PyBool(v),
      int v => PyInt(v),
      double v => PyDouble(v),
      String v => PyString(v),
      List<Object?> v => _container(v, () => _list(v)),
      Map<Object?, Object?> v => _container(v, () => _map(v)),
      Object v => throw ArgumentError.value(
        v,
        'value',
        'Unsupported Python argument',
      ),
    };
  }

  /// 用来检测是否循环引用了
  PyObject _container(Object value, PyObject Function() convert) {
    if (!_active.add(value)) {
      throw ArgumentError(
        'Cyclic Dart containers cannot be converted to Python',
      );
    }
    try {
      return convert();
    } finally {
      _active.remove(value);
    }
  }

  PyList _list(List<Object?> values) => ResourceScope.returning(() {
    final list = PyList(0);
    for (final value in values) {
      list.add(toPyObject(value));
    }
    return list;
  });

  PyDict _map(Map<Object?, Object?> values) => ResourceScope.returning(() {
    final dict = PyDict();
    for (final entry in values.entries) {
      final key = toPyObject(entry.key);
      final value = toPyObject(entry.value);
      dict.setElementAt(key, value);
    }
    return dict;
  });
}
