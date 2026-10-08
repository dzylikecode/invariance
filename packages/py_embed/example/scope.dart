import 'package:py_embed/py_embed.dart';

void main() {
  final PyList list = Py.using((scope) {
    final list = scope(PyList(0));
    for (final value in [3, 1, 2]) {
      list.add(scope(PyInt(value)));
    }
    return scope.escape(list);
  });

  Py.using((scope) {
    scope(list); // Take ownership of the escaped reference.
    final builtins = scope(PyModule('builtins'));
    final sorted = scope(builtins.getAttr('sorted'));
    final result = scope(sorted.forward([list]));
    print(result); // [1, 2, 3]
  });
}
