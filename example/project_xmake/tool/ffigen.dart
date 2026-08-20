import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');
  FfiGenerator(
    output: .new(dartFile: packageRoot.resolve('lib/src/project_xmake.g.dart')),
    headers: .new(
      entryPoints: [
        packageRoot.resolve('include/project_xmake.h'),
      ],
      include: (header) => header.path.contains('project_xmake'),
    ),
    structs: .includeAll,
    functions: .includeAll,
    typedefs: .includeAll,
  ).generate();
}
