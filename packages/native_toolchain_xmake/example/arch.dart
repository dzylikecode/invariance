import 'package:code_assets/code_assets.dart';

void main() {
  final hostOS = OS.current;
  final hostArchitecture = Architecture.current;

  print(hostOS);           // 例如 linux
  print(hostArchitecture); // 例如 x64
  print('${hostOS}_$hostArchitecture'); // 例如 linux_x64
}