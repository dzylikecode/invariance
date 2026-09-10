import 'dart:io';

import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main() async {
  print(Platform.version);
  if (await hasXmake()) {
    print(await getXmakeInfo());
  } else {
    print('xmake is not installed.');
  }
}
