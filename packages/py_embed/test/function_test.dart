import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));
  test('receives mixed, keyword-only, absent and empty keyword arguments', () {
    final fn = PyFunction((args, kwargs) {
      final base = args.length == 0 ? 0 : args[0].asInt();
      final offset = kwargs?.elementAtStr('offset')?.asInt() ?? 0;
      return PyInt(base + offset);
    });
    final inspect = PyFunction((args, kwargs) => PyBool(kwargs == null));
    try {
      ResourceScope.scope(() {
        expect(fn.forward([3], kwargs: {'offset': 4}).asInt(), 7);
        expect(fn.forward([], kwargs: {'offset': 5}).asInt(), 5);
        expect(fn.forward([2]).asInt(), 2);
        expect(fn.forward([], kwargs: {}).asInt(), 0);
        expect(inspect.call0().asBool(), isTrue);
        expect(inspect.forward([], kwargs: {}).asBool(), isFalse);
      });
    } finally {
      inspect.dispose();
      fn.dispose();
    }
  });

  test('returning a caller-owned object preserves its reference', () {
    ResourceScope.scope(() {
      final value = PyString('shared result');
      final initialCount = value.ref.count;
      final fn = PyFunction((args, kwargs) {
        return value;
      });
      try {
        ResourceScope.scope(() {
          final result = fn.call0();
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
      ResourceScope.scope(() {
        final builtins = PyModule('builtins');
        final map = builtins.getAttr('map');
        final list = builtins.getAttr('list');
        final values = PyConverter().toPyObject([1, 2]);
        final mapped = map.forward([fn, values]);
        final result = PyList.fromRef(list.forward([mapped]).ref);
        expect(result[0].asInt(), 11);
        expect(result[1].asInt(), 12);
        offset = 20;
        expect(fn.forward([3]).asInt(), 23);
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
      ResourceScope.scope(() => expect(fn.call0().asInt(), 42));
    } finally {
      fn.dispose();
    }
  });

  test('callback arguments and temporaries clean before the call returns', () {
    ResourceScope.scope(() {
      final module = PyModule.fromSource('''order = []
class Probe:
    def __init__(self, name): self.name = name
    def __del__(self): order.append(self.name)
''');
      final constructor = module.getAttr('Probe');
      final input = constructor.forward(['input']);
      final count = input.ref.count;
      late PyObject temp;
      late PyTuple callbackArgs;
      final fn = PyFunction((args, kwargs) {
        callbackArgs = args;
        temp = constructor.forward(['temp']);
        return args[0];
      });
      ResourceScope.scope(() {
        final result = fn.forward([input]);
        expect(result, input);
        expect(input.ref.count, count + 1);
        expect(temp.isDisposed, isTrue);
        expect(callbackArgs.isDisposed, isTrue);
        expect(module.getAttr('order').toString(), "['temp']");
      });
      expect(input.ref.count, count);
    });
  });

  test('callback failure cleans allocated Python objects', () {
    ResourceScope.scope(() {
      final module = PyModule.fromSource('''order = []
class Probe:
    def __del__(self): order.append('deleted')
''');
      final constructor = module.getAttr('Probe');
      final fn = PyFunction((args, kwargs) {
        constructor.call0();
        throw StateError('callback failed');
      });
      expect(fn.call0, throwsA(isA<PyException>()));
      expect(module.getAttr('order').toString(), "['deleted']");
    });
  });

  test(
    'untracking the original function preserves native callback resources',
    () {
      final fn = ResourceScope.returning(
        () => PyFunction((args, _) => args[0]),
      );
      try {
        ResourceScope.scope(() => expect(fn.forward([3]).asInt(), 3));
      } finally {
        fn.dispose();
        fn.dispose();
      }
      expect(fn.isDisposed, isTrue);
    },
  );

  test(
    'disposing an executing callback is rejected without losing ownership',
    () {
      ResourceScope.scope(() {
        late PyFunction fn;
        fn = PyFunction((args, _) {
          expect(fn.dispose, throwsStateError);
          return PyInt(42);
        });
        expect(fn.call0().asInt(), 42);
        expect(fn.isDisposed, isFalse);
      });
    },
  );
}
