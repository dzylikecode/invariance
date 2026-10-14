import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';
import 'package:test/test.dart';

void main() {
  test('len supports containers and Unicode strings', () {
    using((scope) {
      expect(len(scope(PyList(0))), 0);
      expect(len(scope(PyTuple(0))), 0);
      final dict = scope(PyDict());
      dict.setElementAtStr('key', scope(PyInt(42)));
      expect(len(dict), 1);
      expect(len(scope(PyString('你好😀'))), 3);
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
    using((scope) {
      final main = scope(PyModule('__main__'));
      final probe = scope(main.getAttr('builtin_probe'));
      final count = probe.ref.count;
      expect(len(probe), 7);
      expect(repr(probe), '<probe>');
      expect(probe.ref.count, count);
      for (final operation in <PyObject Function()>[
        () => abs(probe),
        () => pow(probe, scope(PyInt(2))),
        () => pow(probe, scope(PyInt(2)), scope(PyInt(3))),
        () => divmod(probe, scope(PyInt(2))),
      ]) {
        using((results) {
          final result = results(operation());
          expect(result.ptr, probe.ptr);
          expect(probe.ref.count, count + 1);
        });
        expect(probe.ref.count, count);
      }
    });
  });

  test('repr and isinstance follow Python semantics', () {
    using((scope) {
      final builtins = scope(PyModule('builtins'));
      final intType = scope(builtins.getAttr('int'));
      final strType = scope(builtins.getAttr('str'));
      final boolValue = scope(PyBool(true));
      expect(isInstance(boolValue, intType), isTrue);
      expect(isInstance(boolValue, strType), isFalse);
      final types = scope(PyTuple(2));
      strType.ref.increment();
      types[0] = strType;
      intType.ref.increment();
      types[1] = intType;
      expect(isInstance(boolValue, types), isTrue);
      expect(repr(scope(PyString('a\nb'))), "'a\\nb'");
    });
  });

  test('built-in errors propagate and leave the interpreter usable', () {
    runString('''
class BrokenBuiltinProbe:
    def __len__(self): return -1
    def __repr__(self): raise RuntimeError('broken repr')
broken_builtin_probe = BrokenBuiltinProbe()
''');
    using((scope) {
      final number = scope(PyInt(2));
      final text = scope(PyString('x'));
      final main = scope(PyModule('__main__'));
      final broken = scope(main.getAttr('broken_builtin_probe'));
      for (final operation in <Object Function()>[
        () => len(number),
        () => abs(text),
        () => pow(number, text),
        () => divmod(number, scope(PyInt(0))),
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
