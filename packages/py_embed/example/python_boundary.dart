import 'dart:async' show Zone, runZoned;

import 'package:py_embed/py_embed.dart' as py;

// Demo only: keep the active PyScope in a Zone.
// Existing py_embed constructors do NOT automatically register references.
// These small wrappers demonstrate where that registration would happen.
final _scopeKey = Object();
py.PyScope get _scope => Zone.current[_scopeKey] as py.PyScope;

T boundary<T>(T Function() action) =>
    py.using((scope) => runZoned(action, zoneValues: {_scopeKey: scope}));

T owned<T extends py.PyObject>(T value) => _scope(value);
py.PyInt integer(int value) => owned(py.PyInt(value));
py.PyModule module(String name) => owned(py.PyModule(name));
py.PyObject attr(py.PyObject object, String name) =>
    owned(object.getAttr(name));
py.PyObject call(py.PyObject fn, List<Object?> args) => owned(fn.forward(args));
T escape<T extends py.PyObject>(T value) => _scope.escape(value);

// Each Python -> Dart call gets its own scope. Return one NEW reference to
// Python before releasing the scope: this also works for borrowed inputs.
py.PyFunction callback(py.PyFunctionCallback action) => py.PyFunction(
  (args, kwargs) => boundary(() {
    _scope.defer(() => print('  Dart callback scope cleaned up'));
    final result = action(args, kwargs);
    result.ref.increment();
    return result;
  }),
);

void main() {
  py.runString('''
def _boundary_demo(fn, x):
    return fn(x, offset=10)
''');

  final result = boundary(() {
    _scope.defer(() => print('Outer Dart scope cleaned up'));
    final add = callback((args, kwargs) {
      // Both of these new references belong to the callback's inner scope.
      final temp = integer(100);
      final offset = kwargs!.elementAtStr('offset')!.asInt(); // Borrowed.
      print('  Python -> Dart: input=${args[0].asInt()}, temp=${temp.asInt()}');
      return integer(args[0].asInt() + offset);
    });
    // PyFunction owns native callback resources and needs dispose, not DECREF.
    _scope.defer(add.dispose);

    final main = module('__main__');
    final pythonFunction = attr(main, '_boundary_demo');
    final input = integer(32);
    print('Dart -> Python');
    final output = call(pythonFunction, [add, input]);
    print('Python -> Dart returned: ${output.asInt()}');
    return escape(output); // This reference survives the outer scope.
  });

  print('Escaped result is still alive: ${result.asInt()}');
  result.ref.discrement(); // The caller now owns this escaped reference.
}
