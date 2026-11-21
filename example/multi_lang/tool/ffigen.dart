import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  final generator = FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/native/multi_lang.g.dart'),
      ),
      recordUseMapping: packageRoot.resolve(
        'lib/src/native/multi_lang.record_use_mapping.g.dart',
      ),
    ),

    input: Input(
      entryPoints: [packageRoot.resolve('backend/cpp/include/multi_lang.h')],
      include: (header) => header.path.contains('multi_lang'),
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
