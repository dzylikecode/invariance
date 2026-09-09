import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  await FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/binding/template_adapter.g.dart'),
      ),
    ),
    input: Input(
      entryPoints: [packageRoot.resolve('include/template_adapter.h')],
      include: (header) => header.path.contains('template_adapter'),
    ),
    visitors: [
      Visitor(
        enumClass: (node) => node.isIncluded = true,
        func: (node) => node.isIncluded = true,
        typealias: (node) => node.isIncluded = .ifUsed,
      ),
    ],
  ).generate();
}
