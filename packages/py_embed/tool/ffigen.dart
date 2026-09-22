import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:py_embed/src/common.dart' as lib;

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  final version = lib.Version.parse('3.10.21');
  final declarations = await readDeclarations(
    packageRoot.resolve('tool/py_3_8_20.cpp'),
  );

  await generateShared(
    version,
    packageRoot,
    funcs: declarations.funcs,
    structs: declarations.structs,
    typealiases: declarations.aliases,
  );
  await generateSpecific(
    version,
    packageRoot,
    funcs: declarations.platformFuncs,
    structs: declarations.platformStructs,
    typealiases: declarations.platformAliases,
  );
}

Future<void> generateSpecific(
  lib.Version version,
  Uri packageRoot, {
  required Set<String> funcs,
  required Set<String> structs,
  required Set<String> typealiases,
}) {
  final name =
      '${Platform.isWindows ? 'windows' : 'posix'}_${version.format(delimiter: '_')}';
  return generateBindings(
    version: version.toString(),
    packageRoot: packageRoot,
    output: packageRoot.resolve('lib/src/binding/$name.g.dart'),
    funcs: funcs,
    structs: structs,
    importType: importFromSymbolFile(
      packageRoot.resolve('lib/src/binding/shared.symbols.yaml'),
    ),
    typealiases: typealiases,
  );
}

Future<void> generateShared(
  lib.Version version,
  Uri packageRoot, {
  required Set<String> funcs,
  required Set<String> structs,
  required Set<String> typealiases,
}) {
  return generateBindings(
    version: version.toString(),
    packageRoot: packageRoot,
    output: packageRoot.resolve('lib/src/binding/shared.g.dart'),
    funcs: funcs,
    structs: structs,
    typealiases: typealiases,
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
  Set<String> typealiases = const {},
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
        typealias: (node) => node.isIncluded = typealiases.contains(node.name)
            ? .always
            : .never,
      ),
    ],
  ).generate();
}

ImportedType? _noImportedTypes(Declaration _) => null;

class Declarations({
  required final Set<String> platformFuncs,
  required final Set<String> platformStructs,
  required final Set<String> platformAliases,
  required final Set<String> funcs,
  required final Set<String> structs,
  required final Set<String> aliases,
});

Future<Declarations> readDeclarations(Uri source) async {
  final content = await File.fromUri(source).readAsString();
  // The C++ file is the editable declaration list. Clangd resolves each name
  // there; ffigen still parses Python.h using the selected names below.
  final withoutComments = content
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  return Declarations(
    platformFuncs: _readTuple(
      withoutComments,
      'platformFuncs',
      functions: true,
    ),
    platformStructs: _readTuple(withoutComments, 'platformStructs'),
    platformAliases: _readTuple(withoutComments, 'platformAlias'),
    funcs: _readTuple(withoutComments, 'funcs', functions: true),
    structs: _readTuple(withoutComments, 'structs'),
    aliases: _readTuple(withoutComments, 'alias'),
  );
}

Set<String> _readTuple(String source, String name, {bool functions = false}) {
  final pattern = functions
      ? RegExp(
          '\\bconst\\s+auto\\s+$name\\s*=\\s*std::tuple\\s*\\{([^}]*)\\}\\s*;',
        )
      : RegExp('\\busing\\s+$name\\s*=\\s*std::tuple\\s*<([^>]*)>\\s*;');
  final matches = pattern.allMatches(source).toList();
  if (matches.length != 1) {
    throw FormatException(
      'Expected exactly one $name tuple in tool/py_3_8_20.cpp',
    );
  }

  final names = <String>{};
  final itemPattern = RegExp(
    functions ? r'^&([A-Za-z_]\w*)$' : r'^([A-Za-z_]\w*)$',
  );
  for (final item in matches.single.group(1)!.split(',')) {
    final value = item.trim();
    if (value.isEmpty) continue;
    final match = itemPattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Unsupported $name entry: $value');
    }
    if (!names.add(match.group(1)!)) {
      throw FormatException('Duplicate $name entry: $value');
    }
  }
  return names;
}
