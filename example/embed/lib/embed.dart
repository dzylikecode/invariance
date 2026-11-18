import 'dart:convert';
import 'dart:ffi';

import 'src/third_party/embed.g.dart' as native;

String readEmbeddedText() {
  // The native library owns this immutable memory; Dart never frees it.
  final bytes = native.file1_data().cast<Uint8>().asTypedList(
    native.file1_size(),
  );
  return utf8.decode(bytes);
}
