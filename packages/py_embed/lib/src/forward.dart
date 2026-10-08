import 'object.dart';
import 'converter.dart';
import 'scope.dart';

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
  /// The result owns one reference; register it with Py.using or release it with ref.discrement().
  /// Unlike callN(), this method never consumes the caller's argument references.
  PyObject forward(
    List<Object?> args, {
    Map<String, Object?>? kwargs,
    PyConverter? converter,
  }) => Py.using((scope) {
    final conversion = converter ?? PyConverter();
    final positional = scope(PyTuple(args.length));
    for (var i = 0; i < args.length; i++) {
      // PyTuple_SetItem consumes the encoded reference, also on failure.
      positional.setElementAt(i, conversion.toPyObject(args[i]));
    }
    PyDict? keywords;
    if (kwargs != null) {
      final dict = scope(PyDict());
      keywords = dict;
      for (final entry in kwargs.entries) {
        final value = scope(conversion.toPyObject(entry.value));
        dict.setElementAtStr(entry.key, value);
      }
    }
    // call() returns a new owned reference which is not registered here.
    return call(positional, keywords);
  });
}
