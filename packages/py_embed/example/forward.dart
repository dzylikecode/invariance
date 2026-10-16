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

// This view borrows its handle; the surrounding ResourceScope.scope owns it.
class PythonValue implements PyObjectWrapper {
  @override
  final PyObject handle;
  PythonValue(this.handle);
}

void main() {
  ResourceScope.scope(() {
    final builtins = PyModule('builtins');
    final repr = builtins.getAttr('repr');
    final handle = PyDouble(3.5);
    final wrapped = PythonValue(handle);
    // The default converter understands wrappers.
    final text = repr.forward([wrapped]);
    print(text.asString());

    final sorted = builtins.getAttr('sorted');
    final result = sorted.forward(
      [
        [3, 1, 2],
      ],
      kwargs: {'reverse': true},
    );
    print(result); // [3, 2, 1]

    // A binding package supplies a converter for domain-specific values.
    final types = PyModule('types');
    final constructor = types.getAttr('SimpleNamespace');
    final point = repr.forward([
      Point(1, 2),
    ], converter: PointConverter(constructor));
    print(point.asString());
  });
}
