import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

const assetName = 'src/project_xmake.g.dart';
const assetId = 'package:project_xmake/$assetName';

final xmakeLibrary = XmakeLibrary(
  target: 'project_xmake_build',
  linkTarget: 'project_xmake',
  libHintName: 'project_xmake',
  assetName: assetName,
);
