import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:test_gbk/test_gbk.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      // flutter need to check this flag
      runCl();
    }
  });
}
