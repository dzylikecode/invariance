import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  test('register takes ownership; retain acquires a separate reference', () {
    Py.using((refs) {
      final value = refs(PyDouble(1.5));
      final before = value.ref.count;
      Py.using((scope) {
        value.ref.increment();
        expect(identical(scope(value), value), isTrue);
        expect(value.ref.count, before + 1);
        expect(identical(scope.retain(value), value), isTrue);
        expect(value.ref.count, before + 2);
      });
      expect(value.ref.count, before);
    });
  });

  test('escape preserves concrete type and releases container temporaries', () {
    Py.using((refs) {
      final item = refs(PyDouble(2.5));
      final before = item.ref.count;
      final list = Py.using((scope) {
        final list = scope(PyList(0));
        list.add(scope.retain(item));
        return scope.escape(list);
      });
      try {
        expect(list.length, 1);
        expect(list.elementAt(0).asDouble(), 2.5);
        expect(item.ref.count, before + 1);
      } finally {
        list.ref.discrement();
      }
      expect(item.ref.count, before);
    });
  });

  test('ordinary return does not escape a registered reference', () {
    Py.using((refs) {
      final value = refs(PyDouble(3.5));
      final before = value.ref.count;
      final result = Py.using((scope) => scope.retain(value));
      expect(identical(result, value), isTrue);
      expect(value.ref.count, before); // Kept alive by the outer owner only.
    });
    expect(Py.using((scope) => 42), 42);
  });

  test(
    'failure releases partially initialized objects and preserves error',
    () {
      Py.using((refs) {
        final value = refs(PyDouble(4.5));
        final before = value.ref.count;
        final failure = StateError('failed');
        expect(
          () => Py.using((scope) {
            final list = scope(PyList(0));
            list.add(scope.retain(value));
            throw failure;
          }),
          throwsA(same(failure)),
        );
        expect(value.ref.count, before);
      });
    },
  );

  test('escape removes one registration without deduplicating references', () {
    Py.using((refs) {
      final value = refs(PyDouble(5.5));
      final before = value.ref.count;
      final result = Py.using((scope) {
        scope.retain(value);
        scope.retain(value);
        return scope.escape(value);
      });
      expect(value.ref.count, before + 1);
      result.ref.discrement();
      expect(value.ref.count, before);
    });
  });

  test('nested scopes transfer ownership explicitly', () {
    Py.using((refs) {
      final value = refs(PyDouble(6.5));
      final before = value.ref.count;
      Py.using((outer) {
        outer(Py.using((inner) => inner.escape(inner.retain(value))));
        expect(value.ref.count, before + 1);
      });
      expect(value.ref.count, before);
    });
  });

  test('unregistered and already escaped references are rejected', () {
    Py.using((refs) {
      final value = refs(PyDouble(7.5));
      Py.using((scope) {
        expect(() => scope.escape(value), throwsArgumentError);
        scope.retain(value);
        final escaped = scope.escape(value);
        try {
          expect(() => scope.escape(value), throwsArgumentError);
        } finally {
          escaped.ref.discrement();
        }
      });
    });
  });

  test('closed scopes reject operations without consuming references', () {
    late PyScope closed;
    Py.using((scope) {
      closed = scope;
    });
    Py.using((refs) {
      final value = refs(PyDouble(8.5));
      final before = value.ref.count;
      expect(() => closed(value), throwsStateError);
      expect(() => closed.retain(value), throwsStateError);
      expect(() => closed.escape(value), throwsStateError);
      expect(value.ref.count, before);
    });
  });

  test('references are released in reverse registration order', () {
    runString('''
_scope_release_order = []
class _ScopeReleaseProbe:
    def __init__(self, name):
        self.name = name
    def __del__(self):
        _scope_release_order.append(self.name)
''');
    Py.using((scope) {
      final main = scope(PyModule('__main__'));
      final constructor = scope(main.getAttr('_ScopeReleaseProbe'));
      Py.using((inner) {
        inner(constructor.forward(['first']));
        inner(constructor.forward(['second']));
      });
      final order = scope(main.getAttr('_scope_release_order'));
      expect(scope(order.getItem(scope(PyInt(0)))).asString(), 'second');
      expect(scope(order.getItem(scope(PyInt(1)))).asString(), 'first');
    });
  });
}
