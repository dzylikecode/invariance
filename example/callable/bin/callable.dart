import 'package:callable/callable.dart';

Future<void> main(List<String> arguments) async {
  var hz = 1000;
  var seconds = 3.0;
  var busyMs = 0;
  for (final argument in arguments) {
    if (argument.startsWith('--hz=')) hz = int.parse(argument.substring(5));
    if (argument.startsWith('--seconds=')) {
      seconds = double.parse(argument.substring(10));
    }
    if (argument.startsWith('--busy-ms=')) {
      busyMs = int.parse(argument.substring(10));
    }
  }

  final result = await runBenchmark(
    BenchmarkConfig(hz: hz, seconds: seconds, busyMilliseconds: busyMs),
  );
  print(result);
}
