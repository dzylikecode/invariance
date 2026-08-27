import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');

  FfiGenerator(
    output: Output(
      dartFile: packageRoot.resolve('lib/src/project_xmake.g.dart'),
      recordUseMapping: packageRoot.resolve(
        'lib/src/project_xmake.record_use_mapping.g.dart',
      ),
    ),

    headers: Headers(
      entryPoints: [packageRoot.resolve('include/project_xmake.h')],
      include: (header) => header.path.contains('project_xmake'),
    ),

    structs: Structs.includeAll,

    functions: Functions(
      include: Declarations.includeAll,
      recordUse: (_) => true,
    ),

    typedefs: Typedefs.includeAll,
  ).generate();
}
