import 'dart:io';

import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

Future<void> main() async {
	print(await getXmakeVersion());
}
