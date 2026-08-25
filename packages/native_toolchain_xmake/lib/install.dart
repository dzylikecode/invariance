import 'dart:io';

Future<String?> runPowershell(String command) async {
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    command,
  ]);
  if (result.exitCode == 0) {
    return null;
  }
  return result.stderr;
}

Future<String?> runBash(String command) async {
  final result = await Process.run('bash', ['-c', command]);
  if (result.exitCode == 0) {
    return null;
  }
  return result.stderr;
}

// see https://xmake.io/zh/guide/quick-start.html
Future<String?> installXmake() async {
  switch (Platform.operatingSystem) {
    case 'windows':
      return runPowershell("winget install Xmake-io.Xmake");
    case 'linux':
      final resultOfCurl = await runBash("curl -fsSL https://xmake.io/shget.text | bash");
      if (resultOfCurl == null) {
        return null;
      }
      final resultOfWget = await runBash("wget https://xmake.io/shget.text -O - | bash");
      return resultOfWget;
    case 'macos':
      return runBash("brew install xmake");
    default:
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
  }
}


Future<bool> installZig() async {
  if (Platform.isWindows) {
    final result = await runPowershell("winget install -e --id zig.zig");
    if (result != null) {
      return false;
    }
    return true;
  } else if (Platform.isMacOS) {
    final resultOfBrew = await runBash("brew install zig");
    if (resultOfBrew == null) {
      return true;
    }
    return false;
  } else {
    throw UnsupportedError(
      'Unsupported platform: ${Platform.operatingSystem}',
    );
  }
}