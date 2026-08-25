import 'package:native_toolchain_xmake/install.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main() async {
  if (!await hasXmake()) {
    print('xmake not found, attempting to install...');
    final result = await installXmake();
    if (result != null) {
      print('Failed to install xmake: $result');
    } else {
      print('xmake installed successfully.');
    }
  } else {
    print('xmake is already installed.');
    print(await getXmakeInfo());
  }
}
