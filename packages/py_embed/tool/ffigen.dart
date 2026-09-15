import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  generatePyConfig('3.8.20', packageRoot);
}

Future<void> generatePyConfig(String version, Uri packageRoot) {
  return FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve(
          'lib/src/binding/py_config_${Platform.isWindows ? 'windows' : 'posix'}.g.dart',
        ),
      ),
      style: const DynamicLibraryBindings(),
    ),

    input: Input(
      entryPoints: [packageRoot.resolve('dist/$version/include/Python.h')],
      include: (header) => header.path.contains('py_embed'),
      compilerOptions: [
        '-I',
        packageRoot.resolve('dist/$version/include').toFilePath(),
        if (Platform.isMacOS) ...['-isysroot', macSdkPath],
        if (Platform.isWindows) ...['-include', 'winsock2.h'],
        if (Platform.isLinux) ...['-include', 'sys/time.h'],
      ],
    ),
    visitors: [
      Visitor(
        struct: (node) {
          node.isIncluded = node.name == 'PyConfig';
        },
        typealias: (node) =>
            node.isIncluded = node.name == 'Py_ssize_t' ? .ifUsed : .never,
      ),
    ],
  ).generate();
}
