import 'package:py_embed/py_embed.dart';

void main() => using((scope) {
  final module = scope(
    PyModule.fromSource('''
class Model:
    def __init__(self, offset):
        self.offset = offset

    def forward(self, x):
        return x + self.offset
''', name: 'my_model'),
  );
  final constructor = scope(module.getAttr('Model'));
  final model = scope(constructor.forward([10]));
  final forward = scope(model.getAttr('forward'));
  print(scope(forward.forward([32])).asInt()); // 42.

  // Omit name for an independent namespace not registered in sys.modules.
  final anonymous = scope(PyModule.fromSource('answer = 42'));
  print(anonymous.getAttrInt('answer')); // 42.
});
