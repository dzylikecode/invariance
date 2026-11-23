import 'native/multi_lang.g.dart' as cpp;
import 'package:ffi/ffi.dart' as ffi;

String greet(String name) => ffi.using((arena) {
  final result = cpp.greet(name.toNativeUtf8(allocator: arena).cast());
  arena.onReleaseAll(() => cpp.freeString(result));
  return result.cast<ffi.Utf8>().toDartString();
});
