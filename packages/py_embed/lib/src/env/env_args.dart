import 'dart:io';

import 'package:path/path.dart' as p;
import 'loader.dart';
import '../common.dart';

final pyVersion = getPyVersionSync();
final pyDll = openEx(getPyDllPathFromVenvSync());

Future<String> runPyShell(String code, [String pyExe = 'python']) async {
  final result = await Process.run(pyExe, ['-c', code]);

  if (result.exitCode != 0) {
    throw ProcessException(
      pyExe,
      ['-c', code],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  return result.stdout.toString().trim();
}

String runPyShellSync(String code, [String pyExe = 'python']) {
  final result = Process.runSync(pyExe, ['-c', code]);

  if (result.exitCode != 0) {
    throw ProcessException(
      pyExe,
      ['-c', code],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  return result.stdout.toString().trim();
}

Future<String> getPyPrefixFromShell([String pyExe = 'python']) =>
    runPyShell('import sys; print(sys.prefix)', pyExe);
Future<String> getPyExecutableFromShell([String pyExe = 'python']) =>
    runPyShell('import sys; print(sys.executable)', pyExe);
Future<String> getPyBasePrefixFromShell([String pyExe = 'python']) =>
    runPyShell('import sys; print(sys.base_prefix)', pyExe);

String getPyPrefixFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.prefix)', pyExe);
String getPyExecutableFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.executable)', pyExe);
String getPyBasePrefixFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.base_prefix)', pyExe);

Version getPyVersionSync([String pyExe = 'python']) {
  final result = Process.runSync(pyExe, ['--version']);

  if (result.exitCode != 0) {
    throw ProcessException(
      pyExe,
      ['--version'],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  final output = result.stdout.toString().trim();
  return .parse(output);
}

String getPyDllPathFromVenvSync([String pyExe = 'python']) {
  final basePrefix = getPyBasePrefixFromShellSync(pyExe);
  final version = getPyVersionSync(pyExe);
  final path = switch (true) {
    _ when Platform.isLinux => p.join(
      basePrefix,
      'lib',
      'libpython${version.major}.${version.minor}.so',
    ),
    _ when Platform.isWindows => p.join(
      basePrefix,
      'python${version.major}.${version.minor}.dll',
    ),
    _ when Platform.isMacOS => p.join(
      basePrefix,
      'lib',
      'libpython${version.major}.${version.minor}.dylib',
    ),
    _ => throw UnsupportedError('Platform not implemented.'),
  };
  if (!File(path).existsSync()) {
    throw Exception('Python shared library not found at $path');
  }
  return path;
}


