import 'dart:ffi';
import 'dart:typed_data';

import 'src/native/embed.g.dart' as native;

/// The resources embedded in the native library.
abstract final class Assets {
  /// The resource at `assets/file1.txt`.
  static const file1Txt = EmbeddedAsset._(_readFile1Txt);

  /// The resource at `assets/fold1/file1.txt`.
  static const fold1File1Txt = EmbeddedAsset._(_readFold1File1Txt);

  // Direct FFI calls let recorded-use analysis identify each resource's symbols.
  static Uint8List _readFile1Txt() =>
      _copyBytes(native.asset_file1_txt_data(), native.asset_file1_txt_size());

  static Uint8List _readFold1File1Txt() => _copyBytes(
    native.asset_fold1_file1_txt_data(),
    native.asset_fold1_file1_txt_size(),
  );
}

/// A resource whose bytes are read from the native library on demand.
final class EmbeddedAsset {
  const new _(this._load);

  final Uint8List Function() _load;

  /// A copy of the resource bytes owned by Dart.
  ///
  /// Changes to the returned list do not affect the embedded resource.
  Uint8List get bytes => _load();
}

Uint8List _copyBytes(Pointer<Uint8> data, int size) {
  if (size == 0) return Uint8List(0);
  return Uint8List.fromList(data.asTypedList(size));
}
