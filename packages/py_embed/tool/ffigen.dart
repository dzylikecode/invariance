import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  await generateShared('3.8.20', packageRoot);
  await generateSpecific('3.8.20', packageRoot);
}

Future<void> generateSpecific(String version, Uri packageRoot) {
  const funcs = {
    'PyConfig_InitPythonConfig',
    'PyConfig_SetString',
    'Py_InitializeFromConfig',
    'PyConfig_Clear',
  };

  const structs = {'PyConfig'};

  return generateBindings(
    version: version,
    packageRoot: packageRoot,
    output: packageRoot.resolve(
      'lib/src/binding/${Platform.isWindows ? 'windows' : 'posix'}.g.dart',
    ),
    funcs: funcs,
    structs: structs,
    importType: importFromSymbolFile(
      packageRoot.resolve('lib/src/binding/shared.symbols.yaml'),
    ),
    ifUsedTypealiases: const {'Py_ssize_t'},
  );
}

Future<void> generateShared(String version, Uri packageRoot) {
  const funcs = {'Py_Finalize', 'PyStatus_Exception'};

  const structs = {'PyStatus'};

  return generateBindings(
    version: version,
    packageRoot: packageRoot,
    output: packageRoot.resolve('lib/src/binding/shared.g.dart'),
    funcs: funcs,
    structs: structs,
    alwaysTypealiases: const {'PyStatus', 'PyObject'},
    symbolFile: SymbolFile(
      Uri.parse('shared.g.dart'),
      packageRoot.resolve('lib/src/binding/shared.symbols.yaml'),
    ),
  );
}

Future<void> generateBindings({
  required String version,
  required Uri packageRoot,
  required Uri output,
  required Set<String> funcs,
  required Set<String> structs,
  Set<String> alwaysTypealiases = const {},
  Set<String> ifUsedTypealiases = const {},
  SymbolFile? symbolFile,
  ImportedType? Function(Declaration declaration)? importType,
}) {
  return FfiGenerator(
    output: Output(
      dart: DartOutput(path: output),
      style: const DynamicLibraryBindings(),
      symbolFile: symbolFile,
    ),
    importType: importType ?? _noImportedTypes,
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
        struct: (node) => node.isIncluded = structs.contains(node.name),
        func: (node) => node.isIncluded = funcs.contains(node.name),
        typealias: (node) => node.isIncluded = switch (node.name) {
          final name when alwaysTypealiases.contains(name) => .always,
          final name when ifUsedTypealiases.contains(name) => .ifUsed,
          _ => .never,
        },
      ),
    ],
  ).generate();
}

ImportedType? _noImportedTypes(Declaration _) => null;
