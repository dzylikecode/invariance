import 'dart:async';
import 'dart:ffi';

import 'binding/callable.g.dart' as g;

class const BenchmarkConfig({
  final int hz = 1000,
  final double seconds = 3,
  final int busyMilliseconds = 0,
});

class const BenchmarkResult({
  required final BenchmarkConfig config,
  required final int sampleCount,
  required final Duration elapsed,
  required final double minUs,
  required final double averageUs,
  required final double p50Us,
  required final double p90Us,
  required final double p99Us,
  required final double p999Us,
  required final double maxUs,
  required final double firstTenthAverageUs,
  required final double lastTenthAverageUs,
}) {
  double get throughput => sampleCount * 1000000 / elapsed.inMicroseconds;

  @override
  String toString() =>
      '''
NativeCallable.listener benchmark
rate=${config.hz} Hz, samples=$sampleCount, Dart busy=${config.busyMilliseconds} ms/10ms
elapsed=${(elapsed.inMicroseconds / 1e6).toStringAsFixed(3)}s, throughput=${throughput.toStringAsFixed(1)} callbacks/s
latency us: min=${minUs.toStringAsFixed(1)}, avg=${averageUs.toStringAsFixed(1)}, p50=${p50Us.toStringAsFixed(1)}, p90=${p90Us.toStringAsFixed(1)}, p99=${p99Us.toStringAsFixed(1)}, p99.9=${p999Us.toStringAsFixed(1)}, max=${maxUs.toStringAsFixed(1)}
trend us: first10%=${firstTenthAverageUs.toStringAsFixed(1)}, last10%=${lastTenthAverageUs.toStringAsFixed(1)}''';
}

double _percentile(List<int> sorted, double fraction) =>
    sorted[((sorted.length - 1) * fraction).round()] / 1000;

Future<BenchmarkResult> runBenchmark([
  BenchmarkConfig config = const BenchmarkConfig(),
]) async {
  if (config.hz <= 0 || config.seconds <= 0 || config.busyMilliseconds < 0) {
    throw ArgumentError(
      'hz and seconds must be positive; busyMilliseconds cannot be negative',
    );
  }

  final sampleCount = (config.hz * config.seconds).round();
  final delays = <int>[];
  final done = Completer<void>();
  final callback = NativeCallable<g.CallableListenerFunction>.listener((
    int nativeTime,
    int sequence,
  ) {
    delays.add(g.callable_now_ns() - nativeTime);
    if (sequence + 1 == sampleCount && !done.isCompleted) done.complete();
  });

  Timer? load;
  if (config.busyMilliseconds > 0) {
    load = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final until = g.callable_now_ns() + config.busyMilliseconds * 1000000;
      while (g.callable_now_ns() < until) {}
    });
  }

  final wall = Stopwatch()..start();
  if (!g.callable_start(
    callback.nativeFunction,
    (1000000000 / config.hz).round(),
    sampleCount,
  )) {
    load?.cancel();
    callback.close();
    throw StateError('Could not start native benchmark');
  }

  try {
    await done.future.timeout(Duration(seconds: config.seconds.ceil() + 30));
  } finally {
    wall.stop();
    load?.cancel();
    g.callable_join();
    callback.close();
  }

  final tenth = (delays.length / 10).ceil();
  final firstAverage =
      delays.take(tenth).reduce((a, b) => a + b) / tenth / 1000;
  final lastAverage =
      delays.skip(delays.length - tenth).reduce((a, b) => a + b) / tenth / 1000;
  delays.sort();
  return BenchmarkResult(
    config: config,
    sampleCount: delays.length,
    elapsed: wall.elapsed,
    minUs: delays.first / 1000,
    averageUs: delays.reduce((a, b) => a + b) / delays.length / 1000,
    p50Us: _percentile(delays, .5),
    p90Us: _percentile(delays, .9),
    p99Us: _percentile(delays, .99),
    p999Us: _percentile(delays, .999),
    maxUs: delays.last / 1000,
    firstTenthAverageUs: firstAverage,
    lastTenthAverageUs: lastAverage,
  );
}
