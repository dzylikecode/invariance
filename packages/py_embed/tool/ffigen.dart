import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:py_embed/src/common.dart' as lib;

import 'utils/fetch_header.dart';
import 'utils/generate_version_wrapper.dart';

const versions = [
  '3.8.20',
  '3.9.25',
  '3.10.21',
  '3.11.16',
  '3.12.14',
  '3.13.15',
];

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  await fetchHeaders(versions, packageRoot);

  final sharedSource = packageRoot.resolve('tool/shared.cpp');
  final shared = await readDeclarations(sharedSource);

  final sharedOutputs = <({String version, String dart, String symbols})>[];
  for (final value in versions) {
    final version = lib.Version.parse(value);
    await generateShared(
      version,
      packageRoot,
      funcs: shared.funcs,
      structs: shared.structs,
      typealiases: shared.aliases,
    );
    final specificSource = packageRoot.resolve(
      'tool/py_${version.format(delimiter: '_')}.cpp',
    );
    final specific = await readDeclarations(specificSource);
    await generateSpecific(
      version,
      packageRoot,
      funcs: specific.funcs,
      structs: specific.structs,
      typealiases: specific.aliases,
    );
    await generateVersionWrapper(version, packageRoot);
    sharedOutputs.add((
      version: value,
      dart: await File.fromUri(
        packageRoot.resolve('lib/src/binding/shared.g.dart'),
      ).readAsString(),
      symbols: await File.fromUri(
        packageRoot.resolve('lib/src/binding/shared.symbols.yaml'),
      ).readAsString(),
    ));
  }

  final first = sharedOutputs.first;
  for (final output in sharedOutputs.skip(1)) {
    if (output.dart != first.dart || output.symbols != first.symbols) {
      final temp = Directory.fromUri(packageRoot.resolve('temp/'));
      for (final value in [first, output]) {
        final directory = Directory.fromUri(
          temp.uri.resolve('${value.version}/'),
        );
        await directory.create(recursive: true);
        await File.fromUri(directory.uri.resolve('shared.g.dart'))
            .writeAsString(value.dart);
        await File.fromUri(directory.uri.resolve('shared.symbols.yaml'))
            .writeAsString(value.symbols);
      }
      throw StateError(
        'Shared bindings differ: ${first.version} vs ${output.version}. '
        'Comparison files written to ${temp.path}',
      );
    }
  }
}

Future<void> generateSpecific(
  lib.Version version,
  Uri packageRoot, {
  required Set<String> funcs,
  required Set<String> structs,
  required Set<String> typealiases,
}) {
  final name = bindingName(version);
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
    funcs: _readTuple(withoutComments, 'funcs', source, functions: true),
    structs: _readTuple(withoutComments, 'structs', source),
    aliases: _readTuple(withoutComments, 'alias', source),
  );
}

Set<String> _readTuple(
  String source,
  String name,
  Uri path, {
  bool functions = false,
}) {
  final pattern = functions
      ? RegExp(
          '\\bconst\\s+auto\\s+$name\\s*=\\s*std::tuple\\s*\\{([^}]*)\\}\\s*;',
        )
      : RegExp('\\busing\\s+$name\\s*=\\s*std::tuple\\s*<([^>]*)>\\s*;');
  final matches = pattern.allMatches(source).toList();
  if (matches.length != 1) {
    throw FormatException(
      'Expected exactly one $name tuple in ${path.toFilePath()}',
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
