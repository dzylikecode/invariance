import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  await FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/binding/callable.g.dart'),
      ),
    ),
    input: Input(
      entryPoints: [packageRoot.resolve('include/callable.h')],
      include: (header) => header.path.contains('callable'),
    ),
    visitors: [
      Visitor(
        typealias: (node) => node.isIncluded = .always,
        func: (node) => node.isIncluded = true,
      ),
    ],
  ).generate();
}
