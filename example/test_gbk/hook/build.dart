import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    print('你好');
    throw "爱你";
  });
}
