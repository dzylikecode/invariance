import 'package:py_embed/py_embed.dart';

class Point {
  final double x, y;
  Point(this.x, this.y);
}

class PointConverter extends PyConverter {
  final PyObject constructor;
  // The caller keeps this constructor alive while using the converter.
  PointConverter(this.constructor);

  @override
  PyObject toPyObject(Object? value) {
    if (value is Point) {
      return constructor.forward([], kwargs: {'x': value.x, 'y': value.y});
    }
    return super.toPyObject(value);
  }
}

// This view borrows its handle; the surrounding using() scope owns it.
class PythonValue implements PyObjectWrapper {
  @override
  final PyObject handle;
  PythonValue(this.handle);
}

void main() {
  Py.using((scope) {
    final builtins = scope(PyModule('builtins'));
    final repr = scope(builtins.getAttr('repr'));
    final handle = scope(PyDouble(3.5));
    final wrapped = PythonValue(handle);
    // The default converter understands wrappers.
    final text = scope(repr.forward([wrapped]));
    print(text.asString());

    final sorted = scope(builtins.getAttr('sorted'));
    final result = scope(
      sorted.forward(
        [
          [3, 1, 2],
        ],
        kwargs: {'reverse': true},
      ),
    );
    print(result); // [3, 2, 1]

    // A binding package supplies a converter for domain-specific values.
    final types = scope(PyModule('types'));
    final constructor = scope(types.getAttr('SimpleNamespace'));
    final point = scope(
      repr.forward([Point(1, 2)], converter: PointConverter(constructor)),
    );
    print(point.asString());
  });
}
