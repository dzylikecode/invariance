import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));
  test('len supports containers and Unicode strings', () {
    ResourceScope.scope(() {
      expect(len(PyList(0)), 0);
      expect(len(PyTuple(0)), 0);
      final dict = PyDict();
      dict.setElementAtStr('key', PyInt(42));
      expect(len(dict), 1);
      expect(len(PyString('你好😀')), 3);
    });
  });

  test('built-ins preserve custom dispatch and argument ownership', () {
    ResourceScope.scope(() {
      final module = PyModule.fromSource('''
class BuiltinProbe:
    def __len__(self): return 7
    def __abs__(self): return self
    def __pow__(self, exponent, modulus=None): return self
    def __divmod__(self, other): return self
    def __repr__(self): return '<probe>'
builtin_probe = BuiltinProbe()
''');
      final probe = module.getAttr('builtin_probe');
      final count = probe.ref.count;
      expect(len(probe), 7);
      expect(repr(probe), '<probe>');
      expect(probe.ref.count, count);
      for (final operation in <PyObject Function()>[
        () => abs(probe),
        () => pow(probe, PyInt(2)),
        () => pow(probe, PyInt(2), PyInt(3)),
        () => divmod(probe, PyInt(2)),
      ]) {
        ResourceScope.scope(() {
          final result = operation();
          expect(result.ptr, probe.ptr);
          expect(probe.ref.count, count + 1);
        });
        expect(probe.ref.count, count);
      }
    });
  });

  test('repr and isinstance follow Python semantics', () {
    ResourceScope.scope(() {
      final builtins = PyModule('builtins');
      final intType = builtins.getAttr('int');
      final strType = builtins.getAttr('str');
      final boolValue = PyBool(true);
      expect(isInstance(boolValue, intType), isTrue);
      expect(isInstance(boolValue, strType), isFalse);
      final types = PyTuple(2);
      types[0] = strType;
      types[1] = intType;
      expect(isInstance(boolValue, types), isTrue);
      expect(repr(PyString('a\nb')), "'a\\nb'");
    });
  });

  test('built-in errors propagate and leave the interpreter usable', () {
    ResourceScope.scope(() {
      final module = PyModule.fromSource('''
class BrokenBuiltinProbe:
    def __len__(self): return -1
    def __repr__(self): raise RuntimeError('broken repr')
broken_builtin_probe = BrokenBuiltinProbe()
''');
      final number = PyInt(2);
      final text = PyString('x');
      final broken = module.getAttr('broken_builtin_probe');
      for (final operation in <Object Function()>[
        () => len(number),
        () => abs(text),
        () => pow(number, text),
        () => divmod(number, PyInt(0)),
        () => isInstance(number, number),
        () => len(broken),
        () => repr(broken),
      ]) {
        expect(operation, throwsA(isA<PyException>()));
        expect(len(text), 1);
      }
    });
  });
}
