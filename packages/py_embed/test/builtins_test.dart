import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  test('len supports containers and Unicode strings', () {
    Py.using((scope) {
      expect(Py.len(scope(PyList(0))), 0);
      expect(Py.len(scope(PyTuple(0))), 0);
      final dict = scope(PyDict());
      dict.setElementAtStr('key', scope(PyInt(42)));
      expect(Py.len(dict), 1);
      expect(Py.len(scope(PyString('你好😀'))), 3);
    });
  });

  test('built-ins preserve custom dispatch and argument ownership', () {
    runString('''
class BuiltinProbe:
    def __len__(self): return 7
    def __abs__(self): return self
    def __pow__(self, exponent, modulus=None): return self
    def __divmod__(self, other): return self
    def __repr__(self): return '<probe>'
builtin_probe = BuiltinProbe()
''');
    Py.using((scope) {
      final main = scope(PyModule('__main__'));
      final probe = scope(main.getAttr('builtin_probe'));
      final count = probe.ref.count;
      expect(Py.len(probe), 7);
      expect(Py.repr(probe), '<probe>');
      expect(probe.ref.count, count);
      for (final operation in <PyObject Function()>[
        () => Py.abs(probe),
        () => Py.pow(probe, scope(PyInt(2))),
        () => Py.pow(probe, scope(PyInt(2)), scope(PyInt(3))),
        () => Py.divmod(probe, scope(PyInt(2))),
      ]) {
        Py.using((results) {
          final result = results(operation());
          expect(result.ptr, probe.ptr);
          expect(probe.ref.count, count + 1);
        });
        expect(probe.ref.count, count);
      }
    });
  });

  test('repr and isinstance follow Python semantics', () {
    Py.using((scope) {
      final builtins = scope(PyModule('builtins'));
      final intType = scope(builtins.getAttr('int'));
      final strType = scope(builtins.getAttr('str'));
      final boolValue = scope(PyBool(true));
      expect(Py.isInstance(boolValue, intType), isTrue);
      expect(Py.isInstance(boolValue, strType), isFalse);
      final types = scope(PyTuple(2));
      strType.ref.increment();
      types[0] = strType;
      intType.ref.increment();
      types[1] = intType;
      expect(Py.isInstance(boolValue, types), isTrue);
      expect(Py.repr(scope(PyString('a\nb'))), "'a\\nb'");
    });
  });

  test('built-in errors propagate and leave the interpreter usable', () {
    runString('''
class BrokenBuiltinProbe:
    def __len__(self): return -1
    def __repr__(self): raise RuntimeError('broken repr')
broken_builtin_probe = BrokenBuiltinProbe()
''');
    Py.using((scope) {
      final number = scope(PyInt(2));
      final text = scope(PyString('x'));
      final main = scope(PyModule('__main__'));
      final broken = scope(main.getAttr('broken_builtin_probe'));
      for (final operation in <Object Function()>[
        () => Py.len(number),
        () => Py.abs(text),
        () => Py.pow(number, text),
        () => Py.divmod(number, scope(PyInt(0))),
        () => Py.isInstance(number, number),
        () => Py.len(broken),
        () => Py.repr(broken),
      ]) {
        expect(operation, throwsA(isA<PyException>()));
        expect(Py.len(text), 1);
      }
    });
  });
}
