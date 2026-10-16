import 'package:resource_scope/resource_scope.dart';

import 'object.dart';
import 'converter.dart';

extension PyObjectForward on PyObject {
  /// Calls this Python callable with Dart positional and keyword arguments.
  ///
  /// Converts null, bool, int, double, String, List, and Map recursively. Dart
  /// lists become Python lists, and maps become dictionaries. Cyclic containers
  /// and unsupported types throw ArgumentError. String conversion follows
  /// [PyString], including its NUL-terminated string limitation.
  /// Shared containers are converted independently, without preserving identity.
  ///
  /// Existing [PyObject] and [PyObjectWrapper] arguments are borrowed for this call: their references
  /// remain owned by the caller. All temporary references are released even if
  /// conversion or the Python call fails. [converter] handles additional types,
  /// including values nested inside lists and maps.
  ///
  /// The result is automatically registered in the caller's active scope.
  /// Outside a scope, the caller must dispose it. Argument ownership is preserved.
  PyObject forward(
    List<Object?> args, {
    Map<String, Object?>? kwargs,
    PyConverter? converter,
  }) => ResourceScope.returning(() {
    final conversion = converter ?? PyConverter();
    final positional = PyTuple(args.length);
    for (var i = 0; i < args.length; i++) {
      // The tuple retains its own reference; conversion temporaries stay scoped.
      positional.setElementAt(i, conversion.toPyObject(args[i]));
    }
    PyDict? keywords;
    if (kwargs != null) {
      final dict = PyDict();
      keywords = dict;
      for (final entry in kwargs.entries) {
        final value = conversion.toPyObject(entry.value);
        dict.setElementAtStr(entry.key, value);
      }
    }
    // returning promotes the result into the caller's scope.
    return call(positional, keywords);
  });
}
