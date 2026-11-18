import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/third_party/embed_text.g.dart';
const assetId = 'package:embed_text/$assetName';

final xmakeLibrary = XmakeLibrary(target: 'embed_text', assetName: assetName);
