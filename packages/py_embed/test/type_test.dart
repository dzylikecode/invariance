import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));
  test('type and object use the built-in type objects', () {
    ResourceScope.scope(() {
      final builtins = PyModule('builtins');
      final value = PyInt(42);
      expect(type(value), builtins.getAttr('int'));
      final instance = object();
      expect(type(instance), builtins.getAttr('object'));
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
    ResourceScope.scope(() {
      final main = PyModule('__main__');
      final base = main.getAttr('TypeTestBase');
      final forward = main.getAttr('type_test_forward');
      final modelClass = newType('Model', [base], {'forward': forward});
      final instance = modelClass.call0();
      expect(instance.getAttrInt('value'), 7);
      expect(isInstance(instance, base), isTrue);
      expect(type(instance), modelClass);
      final method = instance.getAttr('forward');
      expect(method.forward([3]).asInt(), 21);
      final parent = superOf(modelClass, instance);
      final parentMethod = parent.getAttr('forward');
      expect(parentMethod.forward([3]).asInt(), 10);
      // Creation borrows arguments, which remain usable after the call.
      final customInit = main.getAttr('type_test_init');
      final customClass = newType(
        'Custom',
        [base],
        {'__init__': customInit, 'forward': forward},
      );
      final custom = customClass.call0();
      expect(custom.getAttrInt('value'), 9);
      expect(custom.getAttr('forward').forward([3]).asInt(), 27);
    });
  });

  test('newType propagates Python errors and preserves borrowed arguments', () {
    ResourceScope.scope(() {
      final invalidBase = PyInt(42);
      expect(
        () => newType('Invalid', [invalidBase], {}),
        throwsA(isA<PyException>()),
      );
      expect(invalidBase.asInt(), 42);
      final plainClass = newType('Plain', [], {'answer': 42});
      expect(plainClass.call0().getAttrInt('answer'), 42);
    });
  });
}
