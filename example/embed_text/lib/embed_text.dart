import 'dart:convert';
import 'dart:ffi';

import 'src/third_party/embed_text.g.dart' as native;

String readEmbeddedText() {
  // The native library owns this immutable memory; Dart never frees it.
  final bytes = native.embed_text_data().cast<Uint8>().asTypedList(
    native.embed_text_size(),
  );
  return utf8.decode(bytes);
}
