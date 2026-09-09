import 'package:callable/callable.dart';

Future<void> main(List<String> arguments) async {
  final result = await runBenchmark(_parseArguments(arguments));
  print(result);
}

BenchmarkConfig _parseArguments(List<String> arguments) {
  var config = const BenchmarkConfig();

  for (final argument in arguments) {
    final separator = argument.indexOf('=');
    if (separator < 0) {
      throw FormatException('Expected --name=value, got: $argument');
    }
    final name = argument.substring(0, separator);
    final value = argument.substring(separator + 1);
    config = switch (name) {
      '--hz' => config.copyWith(hz: int.parse(value)),
      '--seconds' => config.copyWith(seconds: double.parse(value)),
      '--busy-ms' => config.copyWith(busyMilliseconds: int.parse(value)),
      _ => throw FormatException('Unknown option: $name'),
    };
  }

  return config;
}
