import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

void main() {
  test('type and object use the built-in type objects', () {
    Py.using((scope) {
      final builtins = scope(PyModule('builtins'));
      final value = scope(PyInt(42));
      expect(scope(Py.type(value)), scope(builtins.getAttr('int')));
      final instance = scope(Py.object());
      expect(scope(Py.type(instance)), scope(builtins.getAttr('object')));
    });
  });

  test('newType inherits init, binds methods and supports super', () {
    runString('''
class TypeTestBase:
    def __init__(self): self.value = 7
    def forward(self, x): return self.value + x

def type_test_forward(self, x):
    return self.value * x

def type_test_init(self):
    TypeTestBase.__init__(self)
    self.value = 9
''');
    Py.using((scope) {
      final main = scope(PyModule('__main__'));
      final base = scope(main.getAttr('TypeTestBase'));
      final forward = scope(main.getAttr('type_test_forward'));
      final modelClass = scope(
        Py.newType('Model', [base], {'forward': forward}),
      );
      final instance = scope(modelClass.call0());
      expect(instance.getAttrInt('value'), 7);
      expect(Py.isInstance(instance, base), isTrue);
      expect(scope(Py.type(instance)), modelClass);
      final method = scope(instance.getAttr('forward'));
      expect(scope(method.forward([3])).asInt(), 21);
      final parent = scope(Py.superOf(modelClass, instance));
      final parentMethod = scope(parent.getAttr('forward'));
      expect(scope(parentMethod.forward([3])).asInt(), 10);
      // Creation borrows arguments, which remain usable after the call.
      final customInit = scope(main.getAttr('type_test_init'));
      final customClass = scope(
        Py.newType(
          'Custom',
          [base],
          {'__init__': customInit, 'forward': forward},
        ),
      );
      final custom = scope(customClass.call0());
      expect(custom.getAttrInt('value'), 9);
      expect(scope(scope(custom.getAttr('forward')).forward([3])).asInt(), 27);
    });
  });

  test('newType propagates Python errors and preserves borrowed arguments', () {
    Py.using((scope) {
      final invalidBase = scope(PyInt(42));
      expect(
        () => Py.newType('Invalid', [invalidBase], {}),
        throwsA(isA<PyException>()),
      );
      expect(invalidBase.asInt(), 42);
      final plainClass = scope(Py.newType('Plain', [], {'answer': 42}));
      expect(scope(plainClass.call0()).getAttrInt('answer'), 42);
    });
  });
}
