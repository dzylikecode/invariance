import 'dart:collection';

import 'object.dart';
import 'scope.dart';

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
      handle.ref.increment();
      return handle;
    }
    if (value is PyObject) {
      value.ref.increment();
      return value;
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

  PyList _list(List<Object?> values) => Py.using((scope) {
    final list = scope(PyList(0));
    for (final value in values) {
      list.add(scope(toPyObject(value)));
    }
    return scope.escape(list);
  });

  PyDict _map(Map<Object?, Object?> values) => Py.using((scope) {
    final dict = scope(PyDict());
    for (final entry in values.entries) {
      final key = scope(toPyObject(entry.key));
      final value = scope(toPyObject(entry.value));
      dict.setElementAt(key, value);
    }
    return scope.escape(dict);
  });
}
