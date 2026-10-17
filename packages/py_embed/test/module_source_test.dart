import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

const source = '''
base = 10
class Model:
    def __init__(self, value): self.value = value
    def forward(self, x): return self.value + x + base
''';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));
  test(
    'anonymous modules initialize builtins for imports and class definitions',
    () {
      ResourceScope.scope(() {
        final module = PyModule.fromSource('''
import math
class Model(object):
    def forward(self):
        values = list(range(4))
        return sum(values) + int(math.sqrt(1296))
answer = Model().forward()
count = len([1, 2, 3])
''');
        expect(module.getAttrInt('answer'), 42);
        expect(module.getAttrInt('count'), 3);
        final constructor = module.getAttr('Model');
        final instance = constructor.call0();
        expect(instance.getAttr('forward').call0().asInt(), 42);
      });
      expect(
        () => PyModule.fromSource('raise ValueError("expected")'),
        throwsA(
          isA<PyException>().having(
            (e) => e.type,
            'type',
            contains('ValueError'),
          ),
        ),
      );
    },
  );

  test('named source is importable and supports class pickle round trips', () {
    ResourceScope.scope(() {
      final sys = PyModule('sys');
      final modules = PyDict.fromRef(sys.getAttr('modules').ref);
      try {
        final module = PyModule.fromSource(
          source,
          name: '_py_embed_source_test',
        );
        expect(PyModule('_py_embed_source_test'), module);
        final cls = module.getAttr('Model');
        expect(cls.getAttrString('__module__'), '_py_embed_source_test');
        final model = cls.forward([2]);
        expect(model.getAttr('forward').forward([3]).asInt(), 15);
        final pickle = PyModule('pickle');
        final bytes = pickle.getAttr('dumps').forward([model]);
        final restored = pickle.getAttr('loads').forward([bytes]);
        expect(restored.getAttrInt('value'), 2);
      } finally {
        modules.removeStr('_py_embed_source_test');
      }
    });
  });

  test('anonymous source namespaces are independent and survive returning a function', () {
    final fn = ResourceScope.scope(() {
      final a = PyModule.fromSource('value = 1\ndef read(): return value');
      final b = PyModule.fromSource('value = 2');
      expect(a.getAttrInt('value'), 1);
      expect(b.getAttrInt('value'), 2);
      expect(a == b, isFalse);
      final sys = PyModule('sys');
      final modules = PyDict.fromRef(sys.getAttr('modules').ref);
      expect(modules.elementAtStr('_anonymous'), isNull);
      return a
          .getAttr('read')
          .detachFromScope(); // Function retains its globals.
    });
    ResourceScope.scope(() {
      ResourceScope.track(fn.ref);
      expect(fn.call0().asInt(), 1);
    });
  });

  test(
    'syntax/runtime exceptions propagate and the interpreter remains usable',
    () {
      expect(() => PyModule.fromSource('class :'), throwsA(isA<PyException>()));
      expect(
        () => PyModule.fromSource('raise ValueError("failed")'),
        throwsA(isA<PyException>()),
      );
      ResourceScope.scope(() {
        final module = PyModule.fromSource('answer = 42');
        expect(module.getAttrInt('answer'), 42);
      });
    },
  );

  test('named execution reuses namespace and removes failed modules', () {
    ResourceScope.scope(() {
      final first = PyModule.fromSource('a = 1', name: '_py_embed_reuse_test');
      final second = PyModule.fromSource(
        'b = a + 1',
        name: '_py_embed_reuse_test',
      );
      expect(first, second);
      expect(second.getAttrInt('b'), 2);
      expect(
        () => PyModule.fromSource(
          'raise RuntimeError("fail")',
          name: '_py_embed_reuse_test',
        ),
        throwsA(isA<PyException>()),
      );
      final modules = PyDict.fromRef(PyModule('sys').getAttr('modules').ref);
      expect(modules.elementAtStr('_py_embed_reuse_test'), isNull);
      expect(first.getAttrInt('a'), 1);
    });
  });
}
