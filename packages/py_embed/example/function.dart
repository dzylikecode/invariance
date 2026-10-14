import 'package:py_embed/py_embed.dart';

void main() => using((scope) {
  final offset = 10;
  final add = PyFunction(
    (args, kwargs) => PyInt(args[0].asInt() + offset),
    name: 'add_offset',
  );
  // Register disposal before Python objects that may retain the callback.
  scope.defer(add.dispose);
  final result = scope(add.forward([32]));
  print(result.asInt()); // 42.
});
