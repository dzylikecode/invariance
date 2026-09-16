import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  await generateShared('3.8.20', packageRoot);
  await generateSpecific('3.8.20', packageRoot);
}

Future<void> generateSpecific(String version, Uri packageRoot) {
  const funcs = [
    'PyConfig_InitPythonConfig',
    'PyConfig_SetString',
    'Py_InitializeFromConfig',
    'PyConfig_Clear',
  ];

  const structs = ['PyConfig'];

  return FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve(
          'lib/src/binding/${Platform.isWindows ? 'windows' : 'posix'}.g.dart',
        ),
      ),
      style: const DynamicLibraryBindings(),
    ),

    // PyStatus is generated once in shared.g.dart. Importing its symbol file
    // makes this platform binding refer to that Dart definition instead of
    // emitting another PyStatus class.
    importType: importFromSymbolFile(
      packageRoot.resolve('lib/src/binding/shared.symbols.yaml'),
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
          node.isIncluded = structs.contains(node.name);
        },
        func: (node) => node.isIncluded = funcs.contains(node.name),
        typealias: (node) =>
            node.isIncluded = node.name == 'Py_ssize_t' ? .ifUsed : .never,
      ),
    ],
  ).generate();
}

Future<void> generateShared(String version, Uri packageRoot) {
  const funcs = ['Py_Finalize'];

  const structs = ['PyStatus'];

  return FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/binding/shared.g.dart'),
      ),
      style: const DynamicLibraryBindings(),
      symbolFile: SymbolFile(
        Uri.parse('shared.g.dart'),
        packageRoot.resolve('lib/src/binding/shared.symbols.yaml'),
      ),
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
          node.isIncluded = structs.contains(node.name);
        },
        func: (node) => node.isIncluded = funcs.contains(node.name),
        typealias: (node) => node.isIncluded = .never,
      ),
    ],
  ).generate();
}
