import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/native/project_xmake.g.dart';
const assetId = 'package:project_xmake/$assetName';

final xmakeLibrary = XmakeLibrary(
  target: 'project_xmake',
  assetName: assetName,
);
