import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/third_party/embed.g.dart';
const assetId = 'package:embed/$assetName';

final xmakeLibrary = XmakeLibrary(target: 'embed', assetName: assetName);
