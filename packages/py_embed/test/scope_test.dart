import 'dart:async';

import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));

  test('constructors, aliases and operators use the same resource scope', () {
    late PyObject sum;
    late PyObject alias;
    ResourceScope.scope(() {
      final value = PyDouble(2.5);
      alias = PyObject(value.ref);
      sum = value + PyDouble(1.5);
      expect(sum.asDouble(), 4);
      expect(identical(alias.ref, value.ref), isTrue);
    });
    expect(sum.isDisposed, isTrue);
    expect(alias.isDisposed, isTrue);
    expect(() => sum.ptr, throwsStateError);
    sum.dispose();
  });

  test('manual disposal is idempotent and cancels scoped ownership', () {
    final value = PyDouble(3.5);
    try {
      ResourceScope.scope(() {
        final retained = value.retain();
        expect(value.ref.count, 2);
        retained.dispose();
        retained.dispose();
        expect(value.ref.count, 1);
      });
      expect(value.ref.count, 1);
    } finally {
      value.dispose();
    }
  });

  test('independent references to equal pointers are released separately', () {
    final value = PyDouble(4.5);
    try {
      ResourceScope.scope(() {
        final first = value.retain();
        final second = value.retain();
        expect(first, second);
        expect(identical(first.ref, second.ref), isFalse);
        expect(value.ref.count, 3);
      });
      expect(value.ref.count, 1);
    } finally {
      value.dispose();
    }
  });

  test('body errors release temporary references and preserve the error', () {
    final value = PyDouble(5.5);
    final failure = StateError('body');
    try {
      expect(
        () => ResourceScope.scope(() {
          final list = PyList(0);
          list.add(value.retain());
          throw failure;
        }),
        throwsA(same(failure)),
      );
      expect(value.ref.count, 1);
    } finally {
      value.dispose();
    }
  });

  test('ordinary return is disposed; returning preserves concrete type', () {
    final disposed = ResourceScope.scope(() => PyDouble(7.5));
    expect(disposed.isDisposed, isTrue);
    final PyList result = ResourceScope.returning(() {
      final list = PyList(0);
      list.add(PyDouble(8.5));
      return list;
    });
    try {
      ResourceScope.scope(() => expect(result[0].asDouble(), 8.5));
    } finally {
      result.dispose();
    }
  });

  test(
    'returning promotes to parent; detachFromScope leaves manual ownership',
    () {
      late PyDouble adopted;
      late PyObject detached;
      ResourceScope.scope(() {
        adopted = ResourceScope.returning(() => PyDouble(9.5));
        detached = ResourceScope.scope(() => PyDouble(10.5).detachFromScope());
        expect(adopted.asDouble(), 9.5);
      });
      expect(adopted.isDisposed, isTrue);
      expect(detached.isDisposed, isFalse);
      detached.dispose();
    },
  );

  test('detachToParentScope delegates to the shared reference', () {
    late PyObject alias;
    late PyList original;
    ResourceScope.scope(() {
      ResourceScope.scope(() {
        original = PyList(0);
        alias = PyList.fromRef(original.ref);
        expect(identical(alias.detachToParentScope(), alias), isTrue);
      });
      expect(original.isDisposed, isFalse);
      expect(alias.isDisposed, isFalse);
    });
    expect(original.isDisposed, isTrue);
    expect(alias.isDisposed, isTrue);
  });

  test('detachFromScope through an alias detaches the original reference', () {
    late PyList original;
    ResourceScope.scope(() {
      original = PyList(0);
      PyObject(original.ref).detachFromScope();
    });
    expect(original.isDisposed, isFalse);
    original.dispose();
  });

  test('disposing an outer reference from an inner scope releases it once', () {
    final observer = PyDouble(11.5);
    try {
      ResourceScope.scope(() {
        final value = observer.retain();
        ResourceScope.scope(value.dispose);
        expect(value.isDisposed, isTrue);
        expect(observer.ref.count, 1);
      });
      expect(observer.ref.count, 1);
    } finally {
      observer.dispose();
    }
  });

  test('async scopes track allocations before and after await', () async {
    late PyDouble first;
    late PyDouble second;
    final result = await ResourceScope.scope(() async {
      first = PyDouble(13.5);
      await Future<void>.delayed(Duration.zero);
      second = PyDouble(14.5);
      return (first + second).detachFromScope();
    });
    try {
      expect(first.isDisposed, isTrue);
      expect(second.isDisposed, isTrue);
      expect(result.asDouble(), 28);
    } finally {
      result.dispose();
    }
  });

  test(
    'concurrent async scopes clean independently on success and failure',
    () async {
      final gate = Completer<void>();
      late PyDouble first;
      late PyDouble second;
      final pending = ResourceScope.scope(() async {
        first = PyDouble(1);
        await gate.future;
        expect(second.isDisposed, isTrue);
        expect(first.asDouble(), 1);
      });
      await expectLater(
        ResourceScope.scope(() async {
          second = PyDouble(2);
          await Future<void>.delayed(Duration.zero);
          throw StateError('async failure');
        }),
        throwsStateError,
      );
      gate.complete();
      await pending;
      expect(first.isDisposed, isTrue);
    },
  );

  test('Python temporaries are destroyed before the inner scope returns', () {
    ResourceScope.scope(() {
      final module = PyModule.fromSource('''
order = []
class Probe:
    def __init__(self, name): self.name = name
    def __del__(self): order.append(self.name)
''');
      final constructor = module.getAttr('Probe');
      ResourceScope.scope(() {
        constructor.forward(['first']);
        constructor.forward(['second']);
      });
      final order = PyList.fromRef(module.getAttr('order').ref);
      expect([
        order[0].asString(),
        order[1].asString(),
      ], unorderedEquals(['first', 'second']));
    });
  });

  test(
    'internal returning scopes adopt results and work without an outer scope',
    () {
      late PyObject result;
      ResourceScope.scope(() {
        final module = PyModule.fromSource('def identity(x): return x');
        result = module.getAttr('identity').forward([3]);
        expect(result.asInt(), 3);
        expect(
          PyConverter().toPyObject([
            1,
            {'a': 2},
          ]).toString(),
          "[1, {'a': 2}]",
        );
      });
      expect(result.isDisposed, isTrue);
      final module = PyModule.fromSource('answer = 42');
      try {
        expect(module.getAttrInt('answer'), 42);
      } finally {
        module.dispose();
      }
    },
  );

  test('unmanaged objects outlive enclosing scopes', () {
    late PyDouble value;
    ResourceScope.scope(() {
      value = ResourceScope.unmanaged(() => PyDouble(3.5));
    });
    expect(value.asDouble(), 3.5);
    value.dispose();
  });

  test(
    'late allocations into a closed Zone are disposed and rejected',
    () async {
      final gate = Completer<void>();
      late Future<void> lateWork;
      ResourceScope.scope(() {
        lateWork = () async {
          await gate.future;
          PyDouble(1.5);
        }();
      });
      final failure = expectLater(lateWork, throwsStateError);
      gate.complete();
      await failure;
    },
  );

  test(
    'withContext cleans temporary references and promotes returned resources',
    () {
      ResourceScope.scope(() {
        final module = PyModule.fromSource('''exited = False
class Context:
    def __enter__(self): return 42
    def __exit__(self, *args):
        global exited
        exited = True
''');
        final context = module.getAttr('Context').call0();
        late PyObject temp;
        final result = context.withContext((value) {
          temp = PyDouble(1.5);
          expect(value.asInt(), 42);
          return PyDouble(2.5).detachToParentScope();
        });
        expect(temp.isDisposed, isTrue);
        expect(result.asDouble(), 2.5);
        expect(module.getAttrBool('exited'), isTrue);
      });
    },
  );

  test('disposed references cannot be retained or detached', () {
    final value = PyDouble(1.5)..dispose();
    expect(value.retain, throwsStateError);
    expect(value.detachFromScope, throwsStateError);
    expect(value.detachToParentScope, throwsStateError);
  });
}
