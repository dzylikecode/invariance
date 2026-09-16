import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';


@internal
extension StringToWCharExt on String {
  Pointer<WChar> toNativeWChar({Allocator allocator = ffi.malloc}) {
    // windows platform
    if (sizeOf<WChar>() == 2) {
      return toNativeUtf16(allocator: allocator).cast();
    }

    // linux/mac platform
    final codePoints = runes.toList();
    final len = codePoints.length; // 会迭代，所以缓存一下

    final result = allocator<Uint32>(len + 1);
    final nativeString = result.asTypedList(len + 1);

    nativeString.setRange(0, len, codePoints);
    nativeString[len] = 0;

    return result.cast();
  }
}

@internal
extension WCharExt on Pointer<WChar> {
  String toDartString() =>
      .fromCharCodes([for (var i = 0; this[i] != 0; i++) this[i]]);
}
