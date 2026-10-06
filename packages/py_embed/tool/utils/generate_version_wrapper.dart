import 'dart:io';

import 'package:mustache_template/mustache_template.dart';
import 'package:py_embed/src/common.dart' as lib;

String bindingName(lib.Version version) =>
    '${Platform.isWindows ? 'windows' : 'posix'}_${version.format(delimiter: '_')}';

Future<void> generateVersionWrapper(
  lib.Version version,
  Uri packageRoot,
) async {
  final source = await File.fromUri(
    packageRoot.resolve('tool/version.dart.template'),
  ).readAsString();
  final template = Template(
    source,
    name: 'tool/version.dart.template',
    htmlEscapeValues: false,
  );

  final name = bindingName(version);
  final output = File.fromUri(
    packageRoot.resolve('lib/src/binding/$name.dart'),
  );
  final content = template.renderString({'binding': name});
  if (await output.exists() && await output.readAsString() == content) return;
  await output.writeAsString(content);
}
