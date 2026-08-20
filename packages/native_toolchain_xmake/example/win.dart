import 'dart:io';

void main() {
  if (Platform.isWindows) {
    print(Platform.environment['PROCESSOR_ARCHITECTURE']);
  }
}
