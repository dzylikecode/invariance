import 'package:py_embed/py_embed.dart';

// TODO: isolate

void main() async {
  print('python version: ${pyRuntime.version}');

  while (true) {
    runString("print('hello world')");
    await Future.delayed(const Duration(seconds: 1));
  }
}
