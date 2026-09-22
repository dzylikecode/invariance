import 'dart:io';

import 'package:py_embed/src/common.dart' as lib;

String bindingName(lib.Version version) =>
    '${Platform.isWindows ? 'windows' : 'posix'}_${version.format(delimiter: '_')}';

Future<void> generateVersionWrapper(
  lib.Version version,
  Uri packageRoot,
) async {
  const marker = '{{binding}}';
  final template = await File.fromUri(
    packageRoot.resolve('tool/version.dart.template'),
  ).readAsString();
  if (!template.contains(marker)) {
    throw FormatException('Missing $marker in tool/version.dart.template');
  }

  final name = bindingName(version);
  final output = File.fromUri(
    packageRoot.resolve('lib/src/binding/$name.dart'),
  );
  final content = template.replaceAll(marker, name);
  if (await output.exists() && await output.readAsString() == content) return;
  await output.writeAsString(content);
}
