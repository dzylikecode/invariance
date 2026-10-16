import 'package:py_embed/py_embed.dart';

void main() {
  ResourceScope.scope(() {
    final module = PyModule.fromSource('''
def call_dart(fn, x):
    return fn(x, offset=10)
''');
    // Each Python -> Dart call gets a scope automatically. The bridge retains
    // the returned object for Python before releasing callback temporaries.
    final add = PyFunction((args, kwargs) {
      final input = args[0].asInt();
      final offset = kwargs!.elementAtStr('offset')!.asInt();
      final temp = PyInt(100);
      print('Python -> Dart: input=$input, temp=${temp.asInt()}');
      return PyInt(input + offset);
    });
    final result = module.getAttr('call_dart').forward([add, 32]);
    print('Dart -> Python -> Dart returned: ${result.asInt()}');
  });
}
