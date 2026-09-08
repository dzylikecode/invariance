import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  final generator = FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/project_xmake.g.dart'),
      ),
      recordUseMapping: packageRoot.resolve(
        'lib/src/project_xmake.record_use_mapping.g.dart',
      ),
    ),

    input: Input(
      entryPoints: [packageRoot.resolve('include/project_xmake.h')],
      include: (header) => header.path.contains('project_xmake'),
    ),

    visitors: [
      Visitor(
        func: (node) {
          node.isIncluded = true;
          node.recordUse = true;
        },
        struct: (node) {
          node.isIncluded = true;
        },
        typealias: (node) {
          node.isIncluded = .always;
        },
      ),
    ],
  );

  await generator.generate();
}
