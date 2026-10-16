import 'package:py_embed/py_embed.dart';

void main() => ResourceScope.scope(() {
  final offset = 10;
  final add = PyFunction(
    (args, kwargs) => PyInt(args[0].asInt() + offset),
    name: 'add_offset',
  );
  final result = add.forward([32]);
  print(result.asInt()); // 42.
});
