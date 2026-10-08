import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

PyObject evaluate(String expression) => Py.using((refs) {
  final builtins = refs(PyModule('builtins'));

  final eval = refs(builtins.getAttr('eval'));
  return eval.callN([PyString(expression), PyDict()]);
});

class Label {
  final String value;
  Label(this.value);
}

class LabelConverter extends PyConverter {
  @override
  PyObject toPyObject(Object? value) {
    if (value is Label) {
      return value.value == 'none'
          ? PyObject.getConst(.none)
          : PyString(value.value);
    }
    return super.toPyObject(value);
  }
}

class FailingConverter extends PyConverter {
  @override
  PyObject toPyObject(Object? value) {
    if (value is! PyObject) throw StateError('converter failed');
    return super.toPyObject(value);
  }
}

class RetainingConverter extends PyConverter {
  final PyObject handle;
  RetainingConverter(this.handle);
  @override
  PyObject toPyObject(Object? value) {
    if (value is Label) {
      handle.ref.increment();
      return handle;
    }
    return super.toPyObject(value);
  }
}

class ObjectWrapper implements PyObjectWrapper {
  final PyObject _handle;
  bool _disposed = false;
  int reads = 0;
  ObjectWrapper(this._handle);

  @override
  PyObject get handle {
    reads++;
    if (_disposed) throw StateError('Wrapper disposed');
    return _handle;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _handle.ref.discrement();
  }
}

void main() {
  test('converts scalars, nested containers and keyword arguments', () {
    Py.using((refs) {
      final fn = refs(
        evaluate(
          'lambda *args, **kw: args == (None, True, 1234, 1.5, "中文", '
          '[1, {"x": [False, None]}]) and kw == {"answer": 42}',
        ),
      );

      final result = refs(
        fn.forward(
          [
            null,
            true,
            1234,
            1.5,
            '中文',
            [
              1,
              {
                'x': [false, null],
              },
            ],
          ],
          kwargs: {'answer': 42},
        ),
      );
      expect(result.asBool(), isTrue);
    });
  });

  test('supports no arguments and repeated acyclic containers', () {
    Py.using((refs) {
      final fn = refs(evaluate('lambda: 42'));

      final result = refs(fn.forward([]));
      expect(result.asInt(), 42);
    });
    final shared = [1, 2];
    Py.using((refs) {
      final fn = refs(evaluate('lambda xs: xs == [[1, 2], [1, 2]]'));

      final r = refs(
        fn.forward([
          [shared, shared],
        ]),
      );
      expect(r.asBool(), isTrue);
    });
  });

  test('retains caller-owned objects and returns an owned reference', () {
    Py.using((refs) {
      final value = refs(PyDouble(3.5));

      final fn = refs(evaluate('lambda x: x'));
      final before = value.ref.count;
      final result = fn.forward([value]);
      expect(result.ptr, value.ptr);
      expect(value.ref.count, before + 1);
      result.ref.discrement();
      expect(value.ref.count, before);
    });
  });

  test('accepts borrowed objects without consuming their owners reference', () {
    final list = PyList(1);
    try {
      list.setElementAt(0, PyDouble(4.5));
      final borrowed = list.elementAt(0);
      final before = borrowed.ref.count;
      Py.using((refs) {
        final fn = refs(evaluate('lambda x: None'));
        fn.forward([borrowed]).ref.discrement();
      });
      expect(borrowed.ref.count, before);
      expect(borrowed.asDouble(), 4.5);
    } finally {
      list.ref.discrement();
    }
  });

  test('custom converter handles nested values and explicit Python None', () {
    Py.using((refs) {
      final fn = refs(evaluate('lambda x: x == {"labels": ["hello", None]}'));

      final result = refs(
        fn.forward([
          {
            'labels': [Label('hello'), Label('none')],
          },
        ], converter: LabelConverter()),
      );
      expect(result.asBool(), isTrue);
    });
  });

  test('cleans partial positional, list, map and keyword conversions', () {
    Py.using((refs) {
      final value = refs(PyDouble(5.5));

      final fn = refs(evaluate('lambda *args, **kw: None'));
      final before = value.ref.count;
      for (final args in <List<Object?>>[
        [value, Object()],
        [
          [value, Object()],
        ],
        [
          {'first': value, 'bad': Object()},
        ],
        [
          {value: Object()},
        ],
      ]) {
        expect(() => fn.forward(args), throwsArgumentError);
        expect(value.ref.count, before);
      }
      expect(
        () => fn.forward([value], kwargs: {'ok': value, 'bad': Object()}),
        throwsArgumentError,
      );
      expect(value.ref.count, before);
      expect(
        () => fn.forward([value, Object()], converter: FailingConverter()),
        throwsStateError,
      );
      expect(value.ref.count, before);
      expect(
        () => fn.forward([
          Label('first'),
          Object(),
        ], converter: RetainingConverter(value)),
        throwsArgumentError,
      );
      expect(value.ref.count, before);
    });
  });

  test('cleans references on Python call and dictionary insertion errors', () {
    Py.using((refs) {
      final value = refs(PyDouble(6.5));
      final before = value.ref.count;

      final fn = refs(evaluate('lambda x: 1 / 0'));
      expect(() => fn.forward([value]), throwsA(isA<PyException>()));

      expect(value.ref.count, before);

      final dictFn = refs(evaluate('lambda x: None'));
      expect(
        () => dictFn.forward([
          {<int>[]: value},
        ]),
        throwsA(isA<PyException>()),
      );

      expect(value.ref.count, before);
    });
  });

  test('call0 reports Python exceptions before wrapping a null pointer', () {
    Py.using((refs) {
      final fn = refs(evaluate('lambda: 1 / 0'));
      expect(() => fn.call0(), throwsA(isA<PyException>()));
    });
  });

  test('rejects cycles without leaking earlier arguments', () {
    final list = <Object?>[];
    list.add(list);
    final map = <String, Object?>{};
    map['self'] = map;
    Py.using((refs) {
      final value = refs(PyDouble(7.5));
      final before = value.ref.count;

      final fn = refs(evaluate('lambda *args, **kw: None'));
      for (final invalid in [list, map]) {
        expect(() => fn.forward([value, invalid]), throwsArgumentError);
        expect(value.ref.count, before);
      }
    });
  });
  test(
    'converter works standalone and can be reused after conversion failure',
    () {
      final converter = LabelConverter();
      Py.using((refs) {
        final value = refs(PyDouble(8.5));
        final before = value.ref.count;
        Py.using((refs) {
          final copy = refs(converter.toPyObject(value));
          expect(copy.ptr, value.ptr);
          expect(value.ref.count, before + 1);
        });
        expect(value.ref.count, before);
      });
      final values = <Object?>[Object()];
      expect(() => converter.toPyObject(values), throwsArgumentError);
      values[0] = Label('hello');
      Py.using((refs) {
        final result = refs(converter.toPyObject(values));

        final index = refs(PyInt(0));

        final item = refs(result.getItem(index));
        expect(item.asString(), 'hello');
      });
      final cyclic = <Object?>[];
      cyclic.add(cyclic);
      expect(() => converter.toPyObject(cyclic), throwsArgumentError);
      cyclic.clear();
      Py.using((refs) {
        final result = refs(converter.toPyObject(cyclic));
        expect(result.asBool(), isFalse);
      });
    },
  );
  test(
    'wrapper conversion reads once and returns an independent reference',
    () {
      final wrapper = ObjectWrapper(PyDouble(9.5));
      final result = PyConverter().toPyObject(wrapper);
      try {
        expect(wrapper.reads, 1);
        expect(result.ref.count, 2);
        wrapper.dispose();
        expect(result.ref.count, 1);
        expect(result.asDouble(), 9.5);
      } finally {
        wrapper.dispose();
        result.ref.discrement();
      }
    },
  );

  test('wrappers work in nested containers, map keys and kwargs', () {
    final wrapper = ObjectWrapper(PyDouble(10.5));
    try {
      final before = wrapper.handle.ref.count;
      Py.using((refs) {
        final fn = refs(
          evaluate(
            'lambda xs, mapping, *, value: xs[0] is value and mapping[value] is value',
          ),
        );

        final result = refs(
          fn.forward(
            [
              [wrapper],
              {wrapper: wrapper},
            ],
            kwargs: {'value': wrapper},
          ),
        );
        expect(result.asBool(), isTrue);
      });
      expect(wrapper.handle.ref.count, before);
    } finally {
      wrapper.dispose();
    }
  });

  test('wrapper references survive conversion and Python failures', () {
    final wrapper = ObjectWrapper(PyDouble(11.5));
    final disposed = ObjectWrapper(PyDouble(12.5))..dispose();
    try {
      final before = wrapper.handle.ref.count;
      Py.using((refs) {
        final fn = refs(evaluate('lambda *args: 1 / 0'));
        expect(() => fn.forward([wrapper]), throwsA(isA<PyException>()));
        expect(wrapper.handle.ref.count, before);
        expect(() => fn.forward([wrapper, Object()]), throwsArgumentError);
        expect(wrapper.handle.ref.count, before);
        expect(() => fn.forward([wrapper, disposed]), throwsStateError);
        expect(wrapper.handle.ref.count, before);
      });
    } finally {
      wrapper.dispose();
    }
  });
}
