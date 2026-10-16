import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

PyObject evaluate(String expression) => ResourceScope.returning(() {
  final builtins = PyModule('builtins');
  final eval = builtins.getAttr('eval');
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
      return handle.retain();
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
    _handle.dispose();
  }
}

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));
  test('converts scalars, nested containers and keyword arguments', () {
    ResourceScope.scope(() {
      final fn = evaluate(
        'lambda *args, **kw: args == (None, True, 1234, 1.5, "中文", '
        '[1, {"x": [False, None]}]) and kw == {"answer": 42}',
      );

      final result = fn.forward(
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
      );
      expect(result.asBool(), isTrue);
    });
  });

  test('supports no arguments and repeated acyclic containers', () {
    ResourceScope.scope(() {
      final fn = evaluate('lambda: 42');

      final result = fn.forward([]);
      expect(result.asInt(), 42);
    });
    final shared = [1, 2];
    ResourceScope.scope(() {
      final fn = evaluate('lambda xs: xs == [[1, 2], [1, 2]]');

      final r = fn.forward([
        [shared, shared],
      ]);
      expect(r.asBool(), isTrue);
    });
  });

  test('retains caller-owned objects and returns an owned reference', () {
    ResourceScope.scope(() {
      final value = PyDouble(3.5);

      final fn = evaluate('lambda x: x');
      final before = value.ref.count;
      final result = fn.forward([value]);
      expect(result.ptr, value.ptr);
      expect(value.ref.count, before + 1);
      result.dispose();
      expect(value.ref.count, before);
    });
  });

  test('accepts container lookups without consuming their reference', () {
    ResourceScope.scope(() {
      final list = PyList(1);
      list.setElementAt(0, PyDouble(4.5));
      final value = list.elementAt(0);
      final before = value.ref.count;
      ResourceScope.scope(() {
        final fn = evaluate('lambda x: None');
        fn.forward([value]);
      });
      expect(value.ref.count, before);
      expect(value.asDouble(), 4.5);
    });
  });

  test('custom converter handles nested values and explicit Python None', () {
    ResourceScope.scope(() {
      final fn = evaluate('lambda x: x == {"labels": ["hello", None]}');

      final result = fn.forward([
        {
          'labels': [Label('hello'), Label('none')],
        },
      ], converter: LabelConverter());
      expect(result.asBool(), isTrue);
    });
  });

  test('cleans partial positional, list, map and keyword conversions', () {
    ResourceScope.scope(() {
      final value = PyDouble(5.5);

      final fn = evaluate('lambda *args, **kw: None');
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
    ResourceScope.scope(() {
      final value = PyDouble(6.5);
      final before = value.ref.count;

      final fn = evaluate('lambda x: 1 / 0');
      expect(() => fn.forward([value]), throwsA(isA<PyException>()));

      expect(value.ref.count, before);

      final dictFn = evaluate('lambda x: None');
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
    ResourceScope.scope(() {
      final fn = evaluate('lambda: 1 / 0');
      expect(() => fn.call0(), throwsA(isA<PyException>()));
    });
  });

  test('rejects cycles without leaking earlier arguments', () {
    final list = <Object?>[];
    list.add(list);
    final map = <String, Object?>{};
    map['self'] = map;
    ResourceScope.scope(() {
      final value = PyDouble(7.5);
      final before = value.ref.count;

      final fn = evaluate('lambda *args, **kw: None');
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
      ResourceScope.scope(() {
        final value = PyDouble(8.5);
        final before = value.ref.count;
        ResourceScope.scope(() {
          final copy = converter.toPyObject(value);
          expect(copy.ptr, value.ptr);
          expect(value.ref.count, before + 1);
        });
        expect(value.ref.count, before);
      });
      final values = <Object?>[Object()];
      expect(() => converter.toPyObject(values), throwsArgumentError);
      values[0] = Label('hello');
      ResourceScope.scope(() {
        final result = converter.toPyObject(values);

        final index = PyInt(0);

        final item = result.getItem(index);
        expect(item.asString(), 'hello');
      });
      final cyclic = <Object?>[];
      cyclic.add(cyclic);
      expect(() => converter.toPyObject(cyclic), throwsArgumentError);
      cyclic.clear();
      ResourceScope.scope(() {
        final result = converter.toPyObject(cyclic);
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
        result.dispose();
      }
    },
  );

  test('wrappers work in nested containers, map keys and kwargs', () {
    final wrapper = ObjectWrapper(PyDouble(10.5));
    try {
      final before = wrapper.handle.ref.count;
      ResourceScope.scope(() {
        final fn = evaluate(
          'lambda xs, mapping, *, value: xs[0] is value and mapping[value] is value',
        );

        final result = fn.forward(
          [
            [wrapper],
            {wrapper: wrapper},
          ],
          kwargs: {'value': wrapper},
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
      ResourceScope.scope(() {
        final fn = evaluate('lambda *args: 1 / 0');
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
