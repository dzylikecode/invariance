import 'package:py_embed/py_embed.dart';

void main() {
  final offset = 10;
  final add = PyFunction(
    (args, kwargs) => PyInt(args[0].asInt() + offset),
    name: 'add_offset',
  );
  try {
    using((scope) {
      final result = scope(add.forward([32]));
      print(result.asInt()); // 42.
    });
  } finally {
    // Remove any Python references before disposing the function.
    add.dispose();
  }
}
