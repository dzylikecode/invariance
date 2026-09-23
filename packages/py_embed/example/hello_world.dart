import 'package:py_embed/py_embed.dart';

void main() {
  print('python version: ${pyRuntime.version}');
  
  runString("print('hello world')");
}
