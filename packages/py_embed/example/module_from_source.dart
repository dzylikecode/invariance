import 'package:py_embed/py_embed.dart';

void main() => ResourceScope.scope(() {
  final module = PyModule.fromSource('''
class Model:
    def __init__(self, offset):
        self.offset = offset

    def forward(self, x):
        return x + self.offset
''', name: 'my_model');
  final constructor = module.getAttr('Model');
  final model = constructor.forward([10]);
  final forward = model.getAttr('forward');
  print(forward.forward([32]).asInt()); // 42.

  // Omit name for an independent namespace not registered in sys.modules.
  final anonymous = PyModule.fromSource('answer = 42');
  print(anonymous.getAttrInt('answer')); // 42.
});
