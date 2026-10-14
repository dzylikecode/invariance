import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  test('receives mixed, keyword-only, absent and empty keyword arguments', () {
    final fn = PyFunction((args, kwargs) {
      final base = args.length == 0 ? 0 : args[0].asInt();
      final offset = kwargs?.elementAtStr('offset')?.asInt() ?? 0;
      return PyInt(base + offset);
    });
    final inspect = PyFunction((args, kwargs) => PyBool(kwargs == null));
    try {
      using((scope) {
        expect(scope(fn.forward([3], kwargs: {'offset': 4})).asInt(), 7);
        expect(scope(fn.forward([], kwargs: {'offset': 5})).asInt(), 5);
        expect(scope(fn.forward([2])).asInt(), 2);
        expect(scope(fn.forward([], kwargs: {})).asInt(), 0);
        expect(scope(inspect.call0()).asBool(), isTrue);
        expect(scope(inspect.forward([], kwargs: {})).asBool(), isFalse);
      });
    } finally {
      inspect.dispose();
      fn.dispose();
    }
  });

  test('returning a retained object transfers only the new reference', () {
    using((scope) {
      final value = scope(PyString('shared result'));
      final initialCount = value.ref.count;
      final fn = PyFunction((args, kwargs) {
        value.ref.increment();
        return value;
      });
      try {
        using((results) {
          final result = results(fn.call0());
          expect(result, value);
          expect(value.ref.count, initialCount + 1);
        });
        expect(value.ref.count, initialCount);
      } finally {
        fn.dispose();
      }
    });
  });

  test('Python invokes a captured Dart closure with positional arguments', () {
    var offset = 10;
    final fn = PyFunction(
      (args, kwargs) => PyInt(args[0].asInt() + offset),
      name: 'add',
    );
    try {
      using((scope) {
        final builtins = scope(PyModule('builtins'));
        final map = scope(builtins.getAttr('map'));
        final list = scope(builtins.getAttr('list'));
        final values = scope(PyConverter().toPyObject([1, 2]));
        final mapped = scope(map.forward([fn, values]));
        final result = PyList.fromHandle(scope(list.forward([mapped])).ptr);
        expect(result[0].asInt(), 11);
        expect(result[1].asInt(), 12);
        offset = 20;
        expect(scope(fn.forward([3])).asInt(), 23);
      });
    } finally {
      fn.dispose();
    }
  });

  test('Dart exceptions become Python RuntimeError and calls can recover', () {
    var fail = true;
    final fn = PyFunction((args, kwargs) {
      if (fail) throw StateError('callback failed');
      return PyInt(42);
    });
    try {
      expect(
        fn.call0,
        throwsA(
          isA<PyException>()
              .having((e) => e.type, 'type', contains('RuntimeError'))
              .having((e) => e.message, 'message', contains('callback failed')),
        ),
      );
      fail = false;
      using((scope) => expect(scope(fn.call0()).asInt(), 42));
    } finally {
      fn.dispose();
    }
  });
}
