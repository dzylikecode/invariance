import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/native/multi_lang.g.dart';
const assetId = 'package:multi_lang/$assetName';

final xmakeLibrary = XmakeLibrary(
  target: 'multi_lang',
  assetName: assetName,
);
