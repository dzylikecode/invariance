import 'package:py_embed/py_embed.dart';

void main() {
  final PyList list = ResourceScope.returning(() {
    final list = PyList(0);
    for (final value in [3, 1, 2]) {
      list.add(PyInt(value));
    }
    return list;
  });

  ResourceScope.scope(() {
    ResourceScope.track(list.ref); // Adopt the manually owned reference.
    final builtins = PyModule('builtins');
    final sorted = builtins.getAttr('sorted');
    final result = sorted.forward([list]);
    print(result); // [1, 2, 3]
  });
}
